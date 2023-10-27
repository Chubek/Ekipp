
%{
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <wchar.h>
#include <math.h>

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
extern   void     yyerror(char* err);
extern   FILE*    output;
extern   FILE*    yyin;
extern   char	  keyletter;

extern  wchar_t*  aux_prim;
extern  wchar_t*  aux_sec;
extern	wchar_t*  aux_tert;

extern  char* 	  exec_cmd;
extern  wchar_t*  exec_strcmp;
extern  wchar_t*  exec_streq;
extern  wchar_t*  exec_strne;

extern  char*	  reg_input;
extern  char*	  reg_pattern;
extern  wchar_t*  reg_matchmsg;
extern  wchar_t*  reg_nomatchmsg;

extern 	char*	  delim_command;
extern  int   	  current_divert;

void 	yyinvoke(wchar_t* code);
void	yyreflect(char* line);
int	yyparse(void);
bool  	yyexpand = false;


#define OUTPUT(ws) 	fputws(ws, output)
%}

%token ENGAGE_SIGIL SEARCH_SIGIL AUX_SIGIL ARGNUM_SIGIL COND_SIGIL KEYLETTER
%token TRANSLIT LSDIR CATFILE DATETIME SUBOFFS
%token EXEC EVAL EXECIF MATCHIF REFLECT CURRENT ENGAGE
%token DIVERT UNDIVERT
%token PUSH POP
%token DEFINE UNDEF
%token SIGILS LEFT_TOKENS RIGHT_TOKENS
%token EXIT ERROR PRINT ENVIRON FORMATTED SYSARGS DNL
%token GE LE EQ NE SHR SHL POW INCR DECR
%token NEWLINE ESCAPE
%token DIVNUM ARGNUM NUM IDENT
%token SQUOTE WQUOTE DELIMITED ASCII ARGUMENT

%left  '*' '/' '%' POW
%left  '+' '-'
%right SHL SHR

%union {
	int64_t 	ival;
	int		cval;
	wchar_t*	wval;
	char*		sval;
	size_t		lenv;
}

%type <ival> expr
%type <sval> foreachbody
%type <ival> exitset

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
       | ifexec
       | reflect
       | exit
       | dnlx
       | sigil
       | divert
       | undivert
       ;

body: bodyset
    | argnum
    ;

bodyset : SQUOTE	       {  fputs($<sval>1, output);    }
	| WQUOTE	       {  fputws($<wval>1, output);   }
	;


call : '$' IDENT args	       { 
     					invoke_macro($<wval>2); 
					invoke_dumpargs();
			       }
     | ESCAPE '$' IDENT args   {
					fputc('$', output);
					OUTPUT($<wval>3);
					invoke_printargs(L" ");
					invoke_dumpargs();
			       }
     ;

foreach : foreachset args
	   '[' foreachbody ']' { invoke_dumpargs();		 }
	;

foreachbody : KEYLETTER	       { invoke_printnext();		 }
	    | body	       { OUTPUT($<wval>1);		 }
	    ;

foreachset : ENGAGE_SIGIL
	       '|' ASCII       { keyletter = $<cval>3;	         } 
	   ;

print : printset
          '|' SYSARGS ARGNUM   { print_argv($<ival>4);		 }
      | printset
          '|' ENVIRON SQUOTE   { print_env($<sval>4);		 }
      | printset
          '|' ERROR SQUOTE     { fputs($<sval>4, stderr);	 }
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
	      'q' SQUOTE       { set_token(&quote_right[0], $<sval>3);  }
	 | righttokset
	      'k' SQUOTE       { set_token(&comment_right[0], $<sval>3); }
	 | righttokset
	      'd' SQUOTE       { set_token(&delim_right[0], $<sval>3);  }
	 ;

righttokset : ENGAGE_SIGIL
	       RIGHT_TOKENS
            ;


lefttok : lefttokset
	      'q' SQUOTE       { set_token(&quote_left[0], $<sval>3);  }
	| lefttokset
	      'k' SQUOTE       { set_token(&comment_left[0], $<sval>3); }
	| lefttokset
	      'd' SQUOTE       { set_token(&delim_left[0], $<sval>3);  }
	;

lefttokset : ENGAGE_SIGIL
	     LEFT_TOKENS
	   ;

sigil : sigilset 
        'e' SQUOTE	       { set_token(&engage_sigil[0], $<sval>3);  }
      | sigilset
        'a' SQUOTE	       { set_token(&argnum_sigil[0], $<sval>3); }
      | sigilset
        'c' SQUOTE	       { set_token(&cond_sigil[0], $<sval>3);    }
      | sigilset
        's' SQUOTE	       { set_token(&search_sigil[0], $<sval>3);  }
      | sigilset
        'x' SQUOTE	       { set_token(&aux_sigil[0], $<sval>3);     }
      ;

sigilset : ENGAGE_SIGIL
	    SIGILS
	;

dnlx : ENGAGE_SIGIL DNL		{ dnl();		       }
     ;

pop : popset '|'
          IDENT		       {  pop_stack($<wval>3);         }
    ;

push : pushset '|'
         IDENT '=' body 
	           NEWLINE     { push_stack($<wval>3, $<wval>5); }
     ;

popset : ENGAGE_SIGIL POP;

pushset : ENGAGE_SIGIL PUSH;

undef : undefset '|'
               IDENT	 	{ remove_symbol($<wval>3);      }
      ;

define : defset '|'
	    IDENT '=' body
	    	      NEWLINE  { insert_symbol($<wval>3, $<wval>5); }
       ;

undefset : ENGAGE_SIGIL UNDEF;

defset : ENGAGE_SIGIL DEFINE;

reflect : reflectset '|'
		SQUOTE 	        {  yyreflect($<sval>3);		}

reflectset : ENGAGE_SIGIL
	   	REFLECT
	   ;

searchfile : searchset '|'
	       SQUOTE		{ open_search_close($<sval>2);  }
	   | searchset '|'
	       CURRENT          { yyin_search();		}
	   ;

searchset : SEARCH_SIGIL
	      SQUOTE		{ reg_pattern = $<sval>2;	}
	  ;

ifexec : COND_SIGIL
            SQUOTE '>'
	    WQUOTE '?'
	    WQUOTE ':'
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
	    SQUOTE '>'
	    SQUOTE '?'
	    WQUOTE ':'
	    WQUOTE
	    '|' MATCHIF		{
	    				reg_input       = $<sval>2;
					reg_pattern     = $<sval>3;
					reg_matchmsg    = $<wval>4;
			 	 	reg_nomatchmsg  = $<wval>5;
					ifelse_regmatch();
	    			}
	;

exit : exitset EXIT ';'		{ exit($<ival>1);		    }

exitset : ENGAGE_SIGIL '|' 
		NUM		{ $$ = $<ival>3;		    }
	;

auxil : auxset
         '|' TRANSLIT		{ translit(0); 			    }
      | auxset
         '|' DATETIME		{ format_time();		    }
      | auxset
         '|' SUBOFFS		{ offset();			    }
      | auxset
         '|' LSDIR		{ list_dir();			    }
      | auxset
         '|' CATFILE		{ cat_file();			    }
      ;

auxset : AUX_SIGIL
           WQUOTE	       { set_aux(&aux_prim, $<wval>2); }
       | auxset '1'
	   WQUOTE              { set_aux(&aux_sec, $<wval>3);  }
       | auxset '2'
	   WQUOTE '3' WQUOTE   {
	  				set_aux(&aux_sec, $<wval>3);
					set_aux(&aux_tert, $<wval>4);
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

delimx : delimset '|'
            DELIMITED		{ 
					init_delim_stream($<wval>3,
							$<lenv>$);
					exec_delim_command();
				}
       ;

delimset : execset 
	     '>' SQUOTE		{ delim_command = $<sval>3; 	    }

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

argnum : ARGNUM_SIGIL ARGNUM    { invoke_printarg($<ival>2);     }
       | ARGNUM_SIGIL WQUOTE    { invoke_printargs($<wval>2);    }
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

void yyinvoke(wchar_t*	code) {
	FILE* yyinhold 	= yyin;
	yyin 	 	= fmemopen(code, wcslen(code), "r");
	yyexpand 	= true;
	yyparse();
	fclose(yyin);
	yyin 		= yyinhold;
	yyexpand 	= false;
}

void yyreflect(char* line) {
	yyin 		= fmemopen(line, strlen(line), "r");
	output		= stdout;
	yyparse();
	fclose(yyin);
	fflush(stdout);
}
