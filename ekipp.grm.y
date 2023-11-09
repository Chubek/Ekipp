%{
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <math.h>


#include <unistr.h>
#include <unistdio.h>
#include <gc.h>

#include "ekipp.h"

#define MAX_TOKEN 8

extern	 uint8_t* fmt;
extern   int 	  yylex(void);
extern   void     yyerror(const char* err);
extern   FILE*    yyout;
extern   FILE*    yyin;

extern  char*	  reg_input;
extern  char*	  reg_pattern;
extern  uint8_t*  reg_matchmsg;
extern  uint8_t*  reg_nomatchmsg;

extern 	char*	  delim_command;
extern  FILE*	  current_divert;
extern  uint8_t*  body_code;

extern  void	  yyparse_body(void);
extern  uint8_t*  YYCURSOR;

uint8_t* yydefeval(uint8_t* code);
%}

%token ENGAGE_PREFIX CALL_PREFIX CALL_SUFFIX DEF_PREFIX DLEFT DRIGHT QLEFT QRIGHT
%token ENCLOSED ESC_TEXT REGEX ARGNUM
%token TRANSLIT LSDIR CATFILE DATETIME OFFSET INCLUDE PATSUB SUBSTITUTE
%token EXEC EVAL REFLECT DNL LF EXEC_DELIM IFEXEC
%token ARG_NUM ARG_IDENT ARG_STR IDENT
%token DIVERT UNDIVERT
%token EXIT ERROR PRINT PRINTF ENVIRON FILEPATH SEARCH ARGV CURRENT
%token GE LE EQ NE SHR SHL POW INCR DECR IFEX CHEVRON XCHN_MARK
%token DIVNUM NUM
%token DEFEVAL DEFINE EXCHANGE

%left  '*' '/' '%' POW
%left  '+' '-'
%right SHL SHR

%union {
	int64_t 	ival;
	uint8_t*	sval;
	int		cmpval;
}

%type <ival> expr
%type <sval> quot
%type <sval> dlmt

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
     | call
     | subs
     | pats
     | xchn
     | '\n'
     ;

call : CALL_PREFIX
     	IDENT '(' args ')'     { body_code = get_symbol($<sval>2);
				 yyparse_body();		}
     | CALL_PREFIX
        IDENT CALL_SUFFIX      { fprintf(yyout, "%s", 
					get_symbol($<sval>2));   }
     ;

xchn : DEF_PREFIX
       EXCHANGE '$' IDENT 
       XCHN_MARK IDENT '\n'     { exchange_symbol($<sval>2, 
       						  $<sval>4);	 }

defn : DEF_PREFIX
     	DEFINE '$'
	IDENT CHEVRON 
	quot		       { insert_symbol($<sval>4, 
					$<sval>6);		}
     | DEF_PREFIX
     	DEFEVAL '$'
	IDENT CHEVRON
	quot		       { defeval_insert($<sval>4,
					$<sval>6);		}
     ;

exit : ENGAGE_PREFIX
         EXIT  '\n'	       { exit(EXIT_SUCCESS);		}
     | ENGAGE_PREFIX
         EXIT '$'
	  ARGNUM  '\n'	       { exit($<ival>4);		}
     ;

escp : '\\' ESC_TEXT	      { fputs($<sval>2, yyout);	}
     ;

srch : ENGAGE_PREFIX
         SEARCH '$'
	  quot
	  FILEPATH '\n'     {   reg_pattern = $<sval>4;
	  			open_search_close($<sval>5);   }
     | ENGAGE_PREFIX
         SEARCH '$' 
	  quot
	  CURRENT '\n'      { 	reg_pattern = $<sval>4;
	  			yyin_search();			}
     ;

prnf : ENGAGE_PREFIX
         PRINTF '$'
	  quot { fmt = $<sval>4; } '(' args ')' 
	  		'\n' { print_formatted(); }
     ;


args :
     | argu ',' args	
     | argu
     ;

argu : ARG_NUM			{ invoke_addarg($<sval>1); }
     | ARG_STR			{ invoke_addarg($<sval>1); }
     | ARG_IDENT		{ invoke_addarg(get_symbol($<sval>1)); }
     ;

prnt : ENGAGE_PREFIX
     	PRINT '$' ENVIRON 
		quot  '\n'    { print_env($<sval>5);	}
     | ENGAGE_PREFIX
        PRINT '$' ARGV
	        ARGNUM  '\n'    { print_argv($<ival>5);		}
     ;

trns : ENGAGE_PREFIX
        TRANSLIT '$'
	quot '>'
	quot '&'
	quot '\n'	       { translit($<sval>4,  
					$<sval>6,  
					$<sval>8);		}
     ;

offs : ENGAGE_PREFIX
        OFFSET '$'
	quot '?'
	quot '\n'            { offset($<sval>4, 
				         $<sval>6);	}

     ;

ldir : ENGAGE_PREFIX
        LSDIR '$'
	FILEPATH '\n'          { list_dir($<sval>4);		}
     ;

date : ENGAGE_PREFIX
     	DATETIME '$'
	quot '\n'            { format_time($<sval>4);   }
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

pats : ENGAGE_PREFIX
       PATSUB '$'
       quot '?'
       quot ':'
       quot '\n'	      { patsub($<sval>4, 
       					$<sval>6, $<sval>8);   }

subs : ENGAGE_PREFIX
       SUBSTITUTE '$'
       quot '?'
       quot ':'
       quot '\n'	      { subst($<sval>4, 
       					$<sval>6, $<sval>8);   }

ifex : ENGAGE_PREFIX
     	quot IFEX quot 
     	 '?' quot
	 ':' quot '\n'      { ifelse_execmatch($<sval>2,
					$<sval>4,
					$<sval>6,
					$<sval>8,
					$<cmpval>3);           }
     ;

ifre : ENGAGE_PREFIX
     	REGEX 	'$' 
	quot  '?'
	quot	':'
	quot	'\n'		{ reg_pattern    = $<sval>2;
				  reg_input      = $<sval>4;
				  reg_matchmsg 	 = $<sval>6;
				  reg_nomatchmsg = $<sval>8;
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
	EXEC_DELIM '$' quot
	  '|' dlmt '\n'    { delim_command = $<sval>4;
	  			  init_delim_stream($<sval>6);
				  exec_delim_command();	         }
     ;



exec : ENGAGE_PREFIX
     	EXEC '$' 
	     quot '\n'	       { exec_command($<sval>4);	 }

     ;

dlmt : DLEFT ENCLOSED DRIGHT   { $$ = gc_strdup($<sval>2);       }

quot : QLEFT ENCLOSED QRIGHT   { $$ = gc_strdup($<sval>2);	 }
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

uint8_t* yydefeval(uint8_t* code) {
	FILE* 	in_hold 	= yyin;
	FILE*	out_hold	= yyout;

	uint8_t* result 	= NULL;
	size_t 	 result_len	= 0;

	yyin			= fmemopen((char*)code,
					u8_strlen(code), "r");
	yyout			= open_memstream((char**)&result, 
					&result_len);

	yyparse();

	uint8_t* res_autoalloc  = GC_MALLOC(result_len * sizeof(uint8_t));
	memmove(&res_autoalloc[0], 
		&result[0], result_len * sizeof(uint8_t));
	fclose(yyout);
	fclose(yyin);
	yyin 			= in_hold;
	yyout 			= out_hold;

	return res_autoalloc;
}
