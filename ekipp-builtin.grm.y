%{
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <wchar.h>
#include <math.h>

#include <gc.h>

#include "ekipp.h"

#define MAX_TOKEN 8

extern	 wchar_t* fmt;
extern   int 	  yylex(void);
extern   void     yyerror(const char* err);
extern   FILE*    yyout;
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

extern  wchar_t*  yydefeval(wchar_t*);

wchar_t* yybuiltineval(wchar_t*);



%}

%define parse.error verbose

%token ENGAGE_PREFIX DELIMITED QUOTED ESC_TEXT REGEX
%token TRANSLIT LSDIR CATFILE DATETIME OFFSET INCLUDE
%token EXEC EVAL REFLECT DNL LF EXEC_DELIM
%token DIVERT UNDIVERT
%token EXIT ERROR PRINT PRINTF ENVIRON FILEPATH SEARCH ARGV CURRENT
%token GE LE EQ NE SHR SHL POW INCR DECR
%token DIVNUM ARGNUM NUM ARGUMENT
%token DEFINE_PREFIX DEFINE_TEXT

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

%start prep
%%

prep : 
     | prep main
     ;

main : exit
     | escp
     | srch
     | prnf
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
     | exec
     | eval
     | '\n'
     ;

defn : DEFINE_PREFIX
     	DEFINE_TEXT	      { fputws(yydefeval($<wval>2), 
						yyout);		}

exit : ENGAGE_PREFIX
         EXIT  '\n'	       { exit(EXIT_SUCCESS);		}
     | ENGAGE_PREFIX
         EXIT '$'
	  NUM  '\n'	       { exit($<ival>4);		}
     ;

escp : '\\' ESC_TEXT	      { fputws($<wval>2, yyout);	}
     ;

srch : ENGAGE_PREFIX
         SEARCH '$'
	  FILEPATH '\n'     { open_search_close($<sval>4);   }
     | ENGAGE_PREFIX
         SEARCH '$'
	  CURRENT '\n'      { yyin_search();			}
     ;

prnf : ENGAGE_PREFIX
         PRINTF '$'
	  QUOTED args  '\n'    { fmt = $<wval>4;
	  			 print_formatted();		}
     ;


args : '(' argu ')'
     ;

argu : ARGUMENT			{ invoke_addarg($<wval>1);	}
     | argu ',' ARGUMENT	{ invoke_addarg($<wval>3); 	}
     ;

prnt : ENGAGE_PREFIX
     	PRINT '$' ENVIRON 
		QUOTED  '\n'    { print_env($<sval>5);		}
     | ENGAGE_PREFIX
        PRINT '$' ARGV
	        ARGNUM  '\n'    { print_argv($<ival>5);		}
     ;

trns : ENGAGE_PREFIX
        TRANSLIT '$'
	QUOTED '>'
	QUOTED '&'
	QUOTED '\n'	       { aux_prim = $<wval>4;
				 aux_sec  = $<wval>6;
				 aux_tert = $<wval>8;
				 translit();			}
     ;

offs : ENGAGE_PREFIX
        OFFSET '$'
	QUOTED '?'
	QUOTED '\n'            { aux_prim = $<wval>4;
				 aux_sec  = $<wval>6;
				 offset();			}
     ;

ldir : ENGAGE_PREFIX
        LSDIR '$'
	FILEPATH '\n'          { aux_prim = $<wval>4;
				 list_dir();			}
     ;

date : ENGAGE_PREFIX
     	DATETIME '$'
	QUOTED '\n'            { aux_prim = $<wval>4;
				 format_time();			}
     ;

catf : ENGAGE_PREFIX
        CATFILE '$'
	FILEPATH '\n'          { aux_prim = $<wval>4;
				 cat_file();			}
     ;


incl : ENGAGE_PREFIX
     	INCLUDE '$'
	FILEPATH '\n'          { aux_prim = $<wval>4;
				  cat_file();			}
     ;

pdnl : ENGAGE_PREFIX
     	DNL '\n'	       { dnl();			       } 
     ;

ifex : ENGAGE_PREFIX
     	QUOTED '$'
        QUOTED '?'
	QUOTED ':'
	QUOTED '\n'		{ exec_cmd      = $<sval>2;
				  exec_strcmp   = $<wval>4;
				  exec_streq    = $<wval>6;
				  exec_strne    = $<wval>8;
     ;				  ifelse_execmatch();		}

ifre : ENGAGE_PREFIX
     	REGEX 	'$' 
	QUOTED  '?'
	QUOTED	':'
	QUOTED	'\n'		{ reg_pattern    = $<sval>2;
				  reg_input      = $<sval>4;
				  reg_matchmsg 	 = $<wval>6;
				  reg_nomatchmsg = $<wval>8;
				  ifelse_regmatch();		 }
     ;

udvr : ENGAGE_PREFIX
     	 UNDIVERT '$' 
	 DIVNUM  '\n'    	{  unswitch_output();	
	 			   unset_divert($<ival>4);       }
     ;

divr : ENGAGE_PREFIX
         DIVERT '$' 
	 DIVNUM '\n'	        { set_divert($<ival>4);
	 			  switch_output(current_divert); }
     ;

dlim : ENGAGE_PREFIX
	EXEC_DELIM '$' QUOTED
	  '|' DELIMITED '\n'    { delim_command = $<sval>4;
	  			  init_delim_stream($<wval>6);
				  exec_delim_command();	         }
     ;



exec : ENGAGE_PREFIX
     	EXEC '$' 
	     QUOTED '\n'	{ exec_cmd = $<sval>4;
					exec_command();		 }
     ;

eval : ENGAGE_PREFIX 
        EVAL '$' expr '\n'	{ fprintf(yyout, 
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
     | '(' expr ')'		{ $$ = $<ival>2;		 }
     | NUM  INCR		{ $$ = $<ival>2++;		 }
     | NUM  DECR		{ $$ = $<ival>2++;		 }
     | NUM			{ $$ = $<ival>1;	         }
     ;
%%

#define RET_MAX		655536

wchar_t* yybuiltineval(wchar_t* code) {
	FILE* inhold    = yyin;
	FILE* outhold   = yyout;

	wchar_t* ret 	= GC_MALLOC(RET_MAX * sizeof(wchar_t));

	yyin		= fmemopen(code, wcslen(code), "r");
	yyout		= fmemopen(ret, RET_MAX * sizeof(wchar_t), "w");

	while (yyparse());

	fclose(yyin);
	fclose(yyout);
	
	yyin   = inhold;
	yyout  = outhold;

	return ret;
}
