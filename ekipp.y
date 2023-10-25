%{

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <wchar.h>

#include "ekipp.h"

#define MAX_TOKEN 8

extern   char    quote_left[MAX_TOKEN];
extern   char    quote_right[MAX_TOKEN];
extern   char    comment_left[MAX_TOKEN];
extern   char    comment_right[MAX_TOKEN];
extern   char    delim_left[MAX_TOKEN];
extern   char    delim_right[MAX_TOKEN];
extern   char    argnum_sigil[MAX_TOKEN];
extern   char    engage_sigil[MAX_TOKEN];
extern   char    cond_sigil[MAX_TOKEN];  
extern   char    search_sigil[MAX_TOKEN];
extern   char    aux_sigil[MAX_TOKEN];

extern	 wchar_t* fmt;
extern   int 	  yylex(void);
extern   FILE*    output;
extern   FILE*    yyin;
extern   char	  keyletter;

void 	yyinvoke(wchar_t* code);
int	yyparse(void);
bool  	yyexpand = false;


#define OUTPUT(ws) 	fputws(ws, output)
%}

%token

%start mainop

%%

mainop : call
       | foreach
       | print
       | tok
       | push
       | pop
       | define
       | undef
       | searchfile
       | auxil
       | exec
       | eval
       | delimx
       | ifmatch
       | Ifexec
       ;

body : argnum
     | SQUOTE
     | WQUOTE
     | mainop
     ;


call : '$' IDENT args	       { 
     					invoke_macro($<wval>2); 
					invoke_dumpargs();
			       }
     | ESCAPE '$' IDENT args   {
					fputc('$', output);
					OUTPUT($<wval>3);
					invoke_printargs(L" ");
			       }
     ;

foreach : foreachset args
	   '[' foreachbody ']' { invoke_dumpargs();		 }
	;

foreachbody : KEYLETTER	       { invoke_printnext();		 }
	    | body	       { OUTPUT($1);			 }
	    ;

foreachset : ENGAGE_SIGIL
	       '|' ASCII       { keyletter = $<cval>4;	         } 
	   ;

print : printset
          '|' ARGV ARGNUM      { print_argv($<ival>4);		 }
      | printset
          '|' ENVIRON SQUOTE   { print_env($<sval>4);		 }
      | printset
          '|' FORMATTED fmt    { print_formatted();		 }
      ;

fmt : WQUOTE args  	       { fmt = $<wval>1;		 }
    ;

args : '(' argset ')'

argset : ARGUMENT	        { invoke_addarg($<wval>1);	 }
       | argset ',' ARGUMENT    { invoke_addarg($<wval>3);	 }
       ;

printset : ENGAGE_SIGIL PRINT;

tok : righttok
    | lefttok
    ;

righttok : righttokset
	      'q' SQUOTE       { set_token(&quote_right, $<sval>3);  }
	 | righttokset
	      'c' SQUOTE       { set_token(&comment_right, $<sval>3); }
	 | righttokset
	      'd' SQUOTE       { set_token(&delim_right, $<sval>3);  }
	 ;

righttokset : ENGAGE_SIGIL
	       RIGHT_TOKENS
            ;


lefttok : lefttokset
	      'q' SQUOTE       { set_token(&quote_left, $<sval>3);  }
	| lefttokset
	      'c' SQUOTE       { set_token(&comment_left, $<sval>3); }
	| lefttokset
	      'd' SQUOTE       { set_token(&delim_left, $<sval>3);  }
	;

lefttokset : ENGAGE_SIGIL
	     LEFT_TOKENS
	   ;

sigil : sigilset 
        'e' SQUOTE	       { set_token(&engage_sigil, $<sval>3);  }
      | sigilset
        'a' SQUOTE	       { set_token(&argnum_sigil, $<svaal>3); }
      | sigilset
        'c' SQUOTE	       { set_token(&cond_sigil, $<sval>3);    }
      | sigilset
        's' SQUOTE	       { set_token(&search_sigil, $<sval>3);  }
      | sigilset
        'x' SQUOTE	       { set_token(&aux_sigil, $<sval>3);     }
      | sigilset
        'l' SQUOTE	       { set_token(&call_sigil, $<sval>3);    }
      ;

sigilset : ENGAGE_SIGIL
	    SIGILS
	;

dnl : DNL_TOKEN			{ dnl();			}
    ;

pop : popset '|'
          IDENT			{ $$ = pop_stack($<wval>3);     }
    ;

push : pushset '|'
         IDENT '=' body 
	           NEWLINE     { push_stack($<wval>3, $5);     }
     ;

popset : ENGAGE_SIGIL POP;

pushset : ENGAGE_SIGIL PUSH;

undef : undefset '|'
               IDENT	 	{ remove_symbol($<wval>3);      }
      ;

define : defset '|'
	    IDENT '=' body
	    	      NEWLINE  { insert_symbol($<wval>3, $5);  }
       ;

undefset : ENGAGE_SIGIL UNDEF;

defset : ENGAGE_SIGIL DEFINE;

searchfile : searchset '|'
	       SQUOTE		{ open_search_close($<sval>2);  }
	   | searchset '|'
	       CURRENT          { yyin_search();		}
	   ;

searchset : SEARCH_SIGIL
	      SQUOTE		{ reg_pattern = $<sval>2;	}
	  ;

ifexec : COND_SIGIL
            SQUOTE ','
	    WQUOTE ','
	    WQUOTE ','
	    WQUOTE
	    '|' EXECIF 		{
	    				exec_cmd     = $<sval>2;
					exec_strcmp  = $<wval>3;
					exec_strne   = $<wval>4;
					exec_streq   = $<wval>5;
					ifelse_execmatch();

				}
	;

ifmatch : COND_SIGIL
	    SQUOTE ','
	    SQUOTE ','
	    WQUOTE ','
	    WQUOTE
	    '|' MATCHIF		{
	    				reg_input       = $<sval>2;
					reg_pattern     = $<sval>3;
					reg_matchmsg    = $<wval>4;
				 	reg_nomatchmsg  = $<wval>5;
					ifelse_regmatch();
	    			}
	;

auxil : auxset
         '|' TRANSLIT		{ translit(); 			    }
      | auxset
         '|' DATETIME		{ format_time();		    }
      | auxset
         '|' SUBOFFS		{ offset();			    }
      | auxset
         '|' LSDIR		{ list_dir();			    }
      | auxset
         '|' CATFILE		{ cat_file();			    }
      ;

auxset : AUXIL_SIGIL
           WQUOTE		{ set_auxil(&auxil_prim, $<wval>2); }
       | auxset ','
	   WQUOTE              { set_auxil(&auxil_sec, $<wval>3);  }
       | auxset ','
	   WQUOTE ',' WQUOTE   {
	  				set_auxil(&auxil_sec, $<wval>3);
					set_auxil(&auxil_tert, $<wval>4);
			       }
       ;
         			

undivert : undivset '|'
	           DIVNUM       {      
	                                unset_divert($<ival>3);
					unswitch_output();
				}
	 ;

divert : divset '|' 
                  DIVNUM        {
	   				set_divert($<ival>3);
					switch_output(current_divert);
				}
       ;


undivset : ENGAGE_SIGIL UNDIVERT;
divset : ENGAGE_SIGIL DIVERT;

delimx : execset '|'
            DELIMITED		{ 
					init_delim_stream($<wval>3,
							$<lenv>$);
					exec_delim_command();
				}
       ;

delimset : execset 
	     '>' SQUOTE		{ delim_cmd = $<sval>3; }

exec : execset '|'
           SQUOTE	        { 
	  				exec_cmd = $<wval>3;
					exec_command();
				}
     ;

eval : evalset '|'
             expr		{ fprintf(output, "%ld", $<ival>3); }
     ;

execset : ENGAGE_SIGIL EXEC;

evalset : ENGAGE_SIGIL EVAL;

argnum : ARGNUM_SIGIL ARGNUM    {  yyexpand ? 
       					invoke_printarg($<ival>2)
					: NULL;
				}
       | ARGNUM_SIGIL WQUOTE    { yyexpand ?
       				        invoke_printargs($<wval>2)
					: NULL;
				}
       ;

expr : expr '+' NUM		{ $$ = $<ival>1 + $<ival>3;      }
     | expr '-' NUM		{ $$ = $<ival>1 - $<ival>3;      }
     | expr '*' NUM		{ $$ = $<ival>1 * $<ival>3;      }
     | expr '/' NUM		{ $$ = $<ival>1 / $<ival>3;      }
     | expr '%' NUM		{ $$ = $<ival>1 % $<ival>3;      }
     | expr '>' NUM		{ $$ = $<ival>1 > $<ival>3;      }
     | expr '<' NUM		{ $$ = $<ival>1 < $<ival>3;      }
     | expr GE  NUM		{ $$ = $<ival>1 >= $<ival>3;     }
     | expr LE  NUM		{ $$ = $<ival>1 <= $<ival>3;     }
     | expr EQ  NUM		{ $$ = $<ival>1 == $<ival>3;     }
     | expr NE  NUM		{ $$ = $<ival>1 != $<ival>3;     }
     | expr SHR NUM		{ $$ = $<ival>1 >> $<ival>3;     }
     | expr SHL NUM		{ $$ = $<ival>1 << $<ival>3;     }
     | expr POW NUM		{ $$ = powl($<ival>1, $<ival>3); }
     | INCR NUM			{ $$ = ++$<ival>2;		 }
     | DECR NUM			{ $$ = --$<ival>2;		 }
     | NUM  INCR		{ $$ = $<ival>2++;		 }
     | NUM  DECR		{ $$ = $<ival>2++;		 }
     | NUM			{ $$ = $<ival>1;	         }
     ;
%%

#include "yy.lex.h"

void yyinvoke(wchar_t*	code) {
	FILE* yyinhold 	= yyin;
	yyin 	 	= fmemopen(code, wcslen(code), "r");
	yyexpand 	= true;
	yyparse();
	fclose(yyin);
	yyin 		= yyinhold;
	yyexpand 	= false;
}
