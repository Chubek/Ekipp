%{

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

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

extern   FILE*   output;

int 	yylex(void);
FILE* 	yyin;
%}

%token

%%

righttok : righttokset
	      'q' SQUOTE       { set_token(&quote_right, $<sval>3);  }
	 | righttokset
	      'c' SQUOTE       { set_token(&comment_right, $<sval>3); }
	 | righttokset
	      'd' SQUOTE       { set_token(&delim_right, $<sval>3);  }
	 ;

righttokset : ENGAGE_SIGIL
	       RIGHT_TOKEN
            ;


lefttok : lefttokset
	      'q' SQUOTE       { set_token(&quote_left, $<sval>3);  }
	| lefttokset
	      'c' SQUOTE       { set_token(&comment_left, $<sval>3); }
	| lefttokset
	      'd' SQUOTE       { set_token(&delim_left, $<sval>3);  }
	;

lefttokset : ENGAGE_SIGIL
	     LEFT_TOKEN
	   ;

sigil : sigilset 
        'e' SQUOTE	       { set_token(&engage_sigil, $<sval>3); }
      | sigilset
        'a' SQUOTE	       { set_token(&argnum_sigil, $<svaal>3); }
      | sigilset
        'c' SQUOTE	       { set_token(&cond_sigil, $<sval>3);   }
      | sigilset
        's' SQUOTE	       { set_token(&search_sigil, $<sval>3); }
      | sigilset
        'x' SQUOTE	       { set_token(&aux_sigil, $<sval>3);   }
      ;

sigilset : ENGAGE_SIGIL
	    SIGIL
	;

dnl : DNL_TOKEN			{ dnl();			}
    ;

pop : popset '|'
          IDENT			{ $$ = pop_stack($<wval>3);     }
    ;

push : pushset '|'
         IDENT '=' body		{ push_stack($<wval>3, $5);     }
     ;

popset : ENGAGE_SIGIL POP;

pushset : ENGAGE_SIGIL PUSH;

undef : undefset '|'
               IDENT	 	{ remove_symbol($<wval>3);      }
      ;

define : defset '|'
	      IDENT '=' body    { insert_symbol($<wval>3, $5);  }
       ;

undefset : ENGAGE_SIGIL UNDEF;

defset : ENGAGE_SIGIL DEFINE;

searchfile : searchset '|'
	       SQUOTED		{ open_search_close($<sval>2);  }
	   | searchset '|'
	       CURRENT          { yyin_search();		}
	   ;

searchset : SEARCH_SIGIL
	      SQUOTED		{ reg_pattern = $<sval>2;	}
	  ;

ifexec : COND_SIGIL
            SQUOTED ','
	    WQUOTED ','
	    WQUOTED ','
	    WQUOTED
	    '|' EXECIF 		{
	    				exec_cmd     = $<sval>2;
					exec_strcmp  = $<wval>3;
					exec_strne   = $<wval>4;
					exec_streq   = $<wval>5;
					ifelse_execmatch();

				}
	;

ifmatch : COND_SIGIL
	    SQUOTED ','
	    SQUOTED ','
	    WQUOTED ','
	    WQUOTED
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
           WQUOTED		{ set_auxil(&auxil_prim, $<wval>2); }
       | auxset ','
	   WQUOTED              { set_auxil(&auxil_sec, $<wval>3);  }
       | auxset ','
	   WQUOTED ',' WQUOTED   {
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
					delim_command = $<sval>3;
					exec_delim_command();
				}
       ;

exec : execset '|'
           SQUOTED	        { 
	  				exec_cmd = $<wval>3;
					exec_command();
				}
     ;

eval : evalset '|'
             expr		{ fprintf(output, "%ld", $<ival>3); }
     ;

execset : ENGAGE_SIGIL EXEC;

evalset : ENGAGE_SIGIL EVAL;

argnum : ARGNUM_SIGIL ARGNUM    { invoke_printarg($<ival>2);        }
       | ARGNUM_SIGIL WQUOTED   { invoke_printargs($<wval>2);       }
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
     | NUM			{ $$ = $<ival>1;	         }
     ;






