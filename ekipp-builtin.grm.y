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

%token ENGAGE_PREFIX DELIMITED QUOTED ESC_TEXT REGEX ARGNUM
%token TRANSLIT LSDIR CATFILE DATETIME OFFSET INCLUDE
%token EXEC EVAL REFLECT DNL LF EXEC_DELIM IFEXEC
%token ARG_NUM ARG_IDENT ARG_STR
%token DIVERT UNDIVERT
%token EXIT ERROR PRINT PRINTF ENVIRON FILEPATH SEARCH ARGV CURRENT
%token GE LE EQ NE SHR SHL POW INCR DECR IFEX
%token DIVNUM NUM
%token DEFINE_PREFIX DEFINE_TEXT

%left  '*' '/' '%' POW
%left  '+' '-'
%right SHL SHR

%union {
	int64_t 	ival;
	int		cval;
	wchar_t*	wval;
	uint8_t*	uval;
	struct {
		wchar_t*	wval;
		char*		sval;
		uint8_t*	uval;
	}		qval;
	char*		sval;
	size_t		lenv;
	int		cmpval;
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
     | defn
     | '\n'
     ;

defn : DEFINE_PREFIX
     	DEFINE_TEXT	      { fputws(yydefeval($<wval>2), 
						yyout);		}

exit : ENGAGE_PREFIX
         EXIT  '\n'	       { exit(EXIT_SUCCESS);		}
     | ENGAGE_PREFIX
         EXIT '$'
	  ARGNUM  '\n'	       { exit($<ival>4);		}
     ;

escp : '\\' ESC_TEXT	      { fputws($<wval>2, yyout);	}
     ;

srch : ENGAGE_PREFIX
         SEARCH '$'
	  QUOTED
	  FILEPATH '\n'     {   reg_pattern = $<qval>4.sval;
	  			open_search_close($<sval>5);   }
     | ENGAGE_PREFIX
         SEARCH '$' 
	  QUOTED
	  CURRENT '\n'      { 	reg_pattern = $<qval>4.sval;
	  			yyin_search();			}
     ;

prnf : ENGAGE_PREFIX
         PRINTF '$'
	  QUOTED { fmt = $<qval>4.wval; } '(' args ')' 
	  		'\n' { print_formatted(); }
     ;


args :
     | argu ',' args	
     | argu
     ;

argu : ARG_NUM			{ invoke_addarg($<wval>1); }
     | ARG_STR			{ invoke_addarg($<wval>1); }
     | ARG_IDENT		{ invoke_addarg(get_symbol($<wval>1)); }
     ;

prnt : ENGAGE_PREFIX
     	PRINT '$' ENVIRON 
		QUOTED  '\n'    { print_env($<qval>5.sval);	}
     | ENGAGE_PREFIX
        PRINT '$' ARGV
	        ARGNUM  '\n'    { print_argv($<ival>5);		}
     ;

trns : ENGAGE_PREFIX
        TRANSLIT '$'
	QUOTED '>'
	QUOTED '&'
	QUOTED '\n'	       { translit($<qval>4.uval,  
					$<qval>6.uval,  
					$<qval>8.uval);		}
     ;

offs : ENGAGE_PREFIX
        OFFSET '$'
	QUOTED '?'
	QUOTED '\n'            { offset($<qval>4.wval, 
				         $<qval>6.wval);	}

     ;

ldir : ENGAGE_PREFIX
        LSDIR '$'
	FILEPATH '\n'          { list_dir($<sval>4);		}
     ;

date : ENGAGE_PREFIX
     	DATETIME '$'
	QUOTED '\n'            { format_time($<qval>4.sval);   }
     ;

catf : ENGAGE_PREFIX
        CATFILE '$'
	FILEPATH '\n'          { cat_file($<sval>4);           }
     ;


incl : ENGAGE_PREFIX
     	INCLUDE '$'
	FILEPATH '\n'          { include_file($<sval>4);       }
     ;

pdnl : ENGAGE_PREFIX
     	DNL '\n'	       { dnl();			       } 
     ;

ifex : ENGAGE_PREFIX
     	QUOTED IFEX QUOTED 
     	 '?' QUOTED
	 ':' QUOTED '\n'      { ifelse_execmatch($<qval>2.wval,
					$<qval>4.wval,
					$<qval>6.sval,
					$<qval>8.sval,
					$<cmpval>3);           }
     ;

ifre : ENGAGE_PREFIX
     	REGEX 	'$' 
	QUOTED  '?'
	QUOTED	':'
	QUOTED	'\n'		{ reg_pattern    = $<qval>2.sval;
				  reg_input      = $<qval>4.sval;
				  reg_matchmsg 	 = $<qval>6.wval;
				  reg_nomatchmsg = $<qval>8.wval;
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
	  '|' DELIMITED '\n'    { delim_command = $<qval>4.sval;
	  			  init_delim_stream($<wval>6);
				  exec_delim_command();	         }
     ;



exec : ENGAGE_PREFIX
     	EXEC '$' 
	     QUOTED '\n'	{ exec_command($<qval>4.sval);	 }

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
