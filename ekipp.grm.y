
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

extern   char     quote_left[MAX_TOKEN];
extern   char     quote_right[MAX_TOKEN];
extern   char     comment_left[MAX_TOKEN];
extern   char     comment_right[MAX_TOKEN];
extern   char     delim_left[MAX_TOKEN];
extern   char     delim_right[MAX_TOKEN];
extern   char     engage_sigil[MAX_TOKEN];

extern	 wchar_t* fmt;
extern   int 	  yylex(void);
extern   void     yyerror(const char* err);
extern   FILE*    output;
extern   FILE*    yyin;

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
extern  FILE*	  current_divert;

void 	yyinvoke(wchar_t* code);
void	yyreflect(wchar_t* line);
int	yyparse(void);
bool  	yyexpand = false;
%}

%define parse.error verbose

%token ENGAGE_PREFIX DELIMITED QUOTED ESC_TEXT REGEX
%token TRANSLIT LSDIR CATFILE DATETIME OFFSET INCLUDE
%token EXEC EVAL REFLECT DNL
%token DIVERT UNDIVERT
%token PUSH POP
%token DEFINE UNDEF
%token ENGAGE COMMENT DELIM QUOTE VTOK MODE
%token EXIT ERROR PRINT PRINTF ENVIRON FILEPATH SEARCH ARGV CURRENT
%token GE LE EQ NE SHR SHL POW INCR DECR
%token DIVNUM ARGNUM NUM IDENT ARGUMENT

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

%start main

%%

main : exit
     | mode
     | escp
     | call
     | srch
     | pops
     | push
     | udef
     | defn
     | prnf
     | args
     | argu
     | prnt
     | trns
     | offs
     | ldir
     | date
     | catf
     | incl
     | pdnl
     | ifex
     | ifre
     | udvr
     | divr
     | dlim
     | refl
     | exec
     | eval
     ;

body : argn
     | main
     ;

exit : ENGAGE_PREFIX
         EXIT 		       { exit(EXIT_SUCCESS);		}
     | ENGAGE_PREFIX
         EXIT '$'
	  NUM		       { exit($<ival>4);		}
     ;

mode : ENGAGE_PREFIX
        MODE '$'
	QUOTE 'l' VTOK         { set_token(&quote_left[0],
					$<sval>6);		}
     | ENGAGE_PREFIX
        MODE '$'
	QUOTE 'r' VTOK	       { set_token(&quote_right[0],
	                                $<sval>6);		}
     | ENGAGE_PREFIX
        MODE '$'
	COMMENT 'l' VTOK       { set_token(&comment_left[0],
	                                $<sval>6);		}
     | ENGAGE_PREFIX
        MODE '$' 
	COMMENT 'r' VTOK       { set_token(&comment_right[0],
	                                $<sval>6);		}
     | ENGAGE_PREFIX
     	MODE '$'
	DELIM 'l' VTOK	       { set_token(&delim_left[0],
	                                $<sval>6);		}
     | ENGAGE_PREFIX
        MODE '$'
	DELIM 'r' VTOK	       { set_token(&delim_right[0],
	                                $<sval>6);		}
     | ENGAGE_PREFIX
       MODE '$'
       ENGAGE '>' VTOK	       { set_token(&engage_sigil[0],
        				$<sval>6);		}
     ;

escp : '\\' ESC_TEXT	       { fputws($<wval>2, output);	}
     ;

call : '$' IDENT args	       { invoke_macro($<wval>2);	}
     ;

srch : ENGAGE_PREFIX
         SEARCH '$'
	  FILEPATH	       { open_search_close($<sval>4);   }
     | ENGAGE_PREFIX
         SEARCH '$'
	  CURRENT	       { yyin_search();			}
     ;

pops : ENGAGE_PREFIX
         POP 		       { pop_stack();			}
     ;

push : ENGAGE_PREFIX
         PUSH '$'
	  IDENT body	       { push_stack($<wval>4, 
	  				$<wval>5);		}
     ;

udef : ENGAGE_PREFIX
           UNDEF '$'
	   IDENT	       { remove_symbol($<wval>3);	}
     ;

defn : ENGAGE_PREFIX
         DEFINE '$'
	  IDENT body	       { insert_symbol($<wval>4,
	  					$<wval>5);      }
     ;

prnf : ENGAGE_PREFIX
         PRINTF '$'
	  QUOTED args	       { fmt = $<wval>4;
	  			 print_formatted();		}
     ;

args : '(' argu ')';

argu : ARGUMENT		       { invoke_addarg($<wval>1);       }
     | argu ',' ARGUMENT       { invoke_addarg($<wval>3);	}
     ;

argn : '#' ARGNUM	       { invoke_printarg($<ival>2);	}
     | '#' QUOTED	       { invoke_printargs($<wval>2);    }
     ;

prnt : ENGAGE_PREFIX
     	PRINT '$' ENVIRON 
		QUOTED         { print_env($<sval>5);		}
     | ENGAGE_PREFIX
        PRINT '$' ARGV
	        ARGNUM	       { print_argv($<ival>5);		}
     ;

trns : ENGAGE_PREFIX
        TRANSLIT '$'
	QUOTED '>'
	QUOTED '&'
	QUOTED		       { aux_prim = $<wval>4;
				 aux_sec  = $<wval>6;
				 aux_tert = $<wval>8;
				 translit();			}
     ;

offs : ENGAGE_PREFIX
        OFFSET '$'
	QUOTED '?'
	QUOTED		       { aux_prim = $<wval>4;
				 aux_sec  = $<wval>6;
				 offset();			}
     ;

ldir : ENGAGE_PREFIX
        LSDIR '$'
	FILEPATH	       { aux_prim = $<wval>4;
				 list_dir();			}
     ;

date : ENGAGE_PREFIX
     	DATETIME '$'
	QUOTED		       { aux_prim = $<wval>4;
				 format_time();			}
     ;

catf : ENGAGE_PREFIX
        CATFILE '$'
	FILEPATH	       { aux_prim = $<wval>4;
				 cat_file();			}
     ;


incl : ENGAGE_PREFIX
     	INCLUDE '$'
	FILEPATH		{ aux_prim = $<wval>4;
				  cat_file();			}
     ;

pdnl : ENGAGE_PREFIX
     	DNL			{ dnl();			}
     ;

ifex : ENGAGE_PREFIX
     	QUOTED '$'
        QUOTED '?'
	QUOTED ':'
	QUOTED			{ exec_cmd      = $<sval>2;
				  exec_strcmp   = $<wval>4;
				  exec_streq    = $<wval>6;
				  exec_strne    = $<wval>8;
     ;				  ifelse_execmatch();		}

ifre : ENGAGE_PREFIX
     	REGEX 	'$' 
	QUOTED  '?'
	QUOTED	':'
	QUOTED			{ reg_pattern    = $<sval>2;
				  reg_input      = $<sval>4;
				  reg_matchmsg 	 = $<wval>6;
				  reg_nomatchmsg = $<wval>8;
				  ifelse_regmatch();		 }
     ;

udvr : ENGAGE_PREFIX
     	 UNDIVERT '>' DIVNUM	{ unset_divert($<ival>4);
	 			  unswitch_output();		 }
     ;

divr : ENGAGE_PREFIX
         DIVERT '<' DIVNUM	{ set_divert($<ival>4);
	 			  switch_output(current_divert); }
     ;

dlim : ENGAGE_PREFIX
	EXEC '$' QUOTED
	  '<' DELIMITED		{ delim_command = $<sval>4;
	  			  init_delim_stream($<wval>6,
	  				$<lenv>$);
				  exec_delim_command();	         }
     ;


refl : ENGAGE_PREFIX
        REFLECT '$' QUOTED	{ yyreflect($<wval>4);		 }


exec : ENGAGE_PREFIX
     	EXEC '$' QUOTED		{ exec_cmd = $<sval>4;
					exec_command();		 }
     ;

eval : ENGAGE_PREFIX 
        EVAL '$' expr		{ fprintf(output, 
	 				"%ld", $<ival>4);	 }
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

void yyreflect(wchar_t* line) {
	yyin 		= fmemopen(line, wcslen(line), "r");
	output		= stdout;
	yyparse();
	fclose(yyin);
	fflush(stdout);
}
