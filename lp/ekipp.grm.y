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
#include "machine.h"

#include "machine-gen.i"

#define TOK_MAX	2

#define BB_BOUNDARY (last_compiled = NULL,  /* suppress peephole opt */ \
                     block_insert(vmcodep)) /* for accurate profiling */

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

extern uint8_t engage_prefix_token[TOK_MAX + 1];
extern uint8_t define_prefix_token[TOK_MAX + 1];
extern uint8_t call_prefix_token[TOK_MAX + 1];
extern uint8_t call_suffix_token[TOK_MAX + 1];
extern uint8_t quote_left_token[TOK_MAX + 1];
extern uint8_t quote_right_token[TOK_MAX + 1];
extern uint8_t comment_left_token[TOK_MAX + 1];
extern uint8_t comment_right_token[TOK_MAX + 1];
extern uint8_t delim_left_token[TOK_MAX + 1];
extern uint8_t delim_right_token[TOK_MAX + 1];
extern uint8_t template_delim_left_token[TOK_MAX + 1];
extern uint8_t template_delim_right_token[TOK_MAX + 1];

uint8_t* yydefeval(uint8_t* code);

int nonparams  = 0;
int locals	= 0;

Label *vm_prim;
Inst  *vmcodep;
FILE  *vm_out;
int   vm_debug;
%}

%token ENGAGE_PREFIX CALL_PREFIX CALL_SUFFIX DEF_PREFIX DLEFT DRIGHT QLEFT QRIGHT
%token ENCLOSED ESC_TEXT REGEX ARGNUM
%token TRANSLIT LSDIR CATFILE DATETIME OFFSET INCLUDE PATSUB SUBSTITUTE
%token EXEC EVAL REFLECT DNL LF EXEC_DELIM IFEXEC
%token ARG_NUM ARG_IDENT ARG_STR IDENT
%token DIVERT UNDIVERT
%token EXIT ERROR PRINT PRINTF ENVIRON FILEPATH SEARCH ARGV CURRENT
%token GE LE EQ NE SHR SHL POW DIV AND OR INCR DECR IFEX CHEVRON XCHN_MARK
%token DIVNUM NUM FLOATNUM
%token DEFEVAL DEFINE EXCHANGE
%token FUNC RETURN VAR TYPE ELSE IF DO WHILE FOR END THEN INIT_ASSIGN
%token IMPORT NAMESPACE
%token SQ DQ TBT SQ_TXT DQ_TXT TBT_TXT
%token DELIM_TEMPLATE_BEGIN DELIM_TEMPLATE_END
%token STD_IN STD_OUT STD_ERR THIS_FILE FILE_HANDLE INPUT OUTPUT
%token COMMENTLEFT DELIMLEFT TMPLDELIMLEFT QUOTELEFT
%token COMMENTRIGHT DELIMRIGHT TMPLDELIMRIGHT QUOTERIGHT
%token ENGAGEPREFIX CALLPREFIX DEFPREFIX CALLSUFFIX CHANGETOKEN CHNGVAL
%token TEMPLATE_DELIM_LEFT TEMPLATE_DELIM_RIGHT

%left    '*' '/' '%' POW
%left     '>' '<' LE GE
%right    AND OR SHR SHL '&' '|' '^'
%nonassoc EQ NE

%union {
	intmax_t	ival;
	long double	fval;
	uint8_t*	sval;
	int		tval;
	int		cmpval;
	char		chngval[2];
	Inst*		instp;
	struct Handle {
		uint8_t* name;
		uint8_t* mode;
	}		handle;
}

%type <sval> delimited
%type <ival> expr
%type <instp> elsepart
%type <instp> dopart
%type <sval> quote


%start prep
%%

prep : 
     | prep main
     ;

main : exit
     | escape
     | search
     | printf
     | print
     | translit
     | offset
     | ldir
     | date
     | catf
     | incl
     | pdnl
     | ifexec
     | ifregex
     | undivert
     | divert
     | dlim
     | exec
     | eval
     | define
     | call
     | substitute
     | patsub
     | exchange
     | token
     | template
     | '\n'
     ;

template : DELIM_TEMPLATE_BEGIN program DELIM_TEMPLATE_END
	 ;

program : program function
	| import program
	|;

import : IMPORT NAMESPACE ';' {  resolve_namespace($<sval>2);	}


function : FUNC IDENT   { locals = 0; nonparams = 0; } '(' params ')'
	 vars		{ insert_func($<sval>2, vmcodep, 
	 			locals, nonparams);	}
	 stats RETURN expr ';'
	 END FUNC ';'	{ gen_return(&vmcodep, -adjust(locals)); }
	 ;

params : IDENT ':' TYPE ',' { insert_local($<sval>1, 
       				$<tval>3); } params
       | IDENT ':' TYPE	    { insert_local($<sval>1, 
       				$<tval>3); }
       |;

vars : vars VAR IDENT ':' TYPE ';' { insert_local($<sval>3,
     							$<tval>5);
     					nonparams++;		      }
     | vars IDENT ':' TYPE 
     		INIT_ASSIGN txpr ';' { insert_local($<sval>1, $<tval>3);
					if ($<tval>3 == VAR_INT)
					  gen_storelocalnum(&vmcodep,
					  var_offset($<sval>1));
					else if ($<tval>3 == VAR_STR)
					  gen_storelocalnum(&vmcodep, 
						  var_offset($<sval>1));
					else if ($<tval>3 == VAR_INT)
					  gen_storelocalflt(&vmcodep, 
						  var_offset($<sval>1));									}
     |;

stats : stats stat ';'
      |;

commastats : commastats ',' stats
	   |;


stat : IF txpr THEN   { gen_zbranch(&vmcodep, 0); $<instp>$ = vmcodep; }
       stats	      { $<instp>$ = $<instp>4; }
       elsepart END IF { BB_BOUNDARY; 
       			 vm_target2Cell(vmcodep, $<instp>7[-1]);	}
     | WHILE           { BB_BOUNDARY; $<instp>$ = vmcodep;		} 
       txpr DO         { gen_zbranch(&vmcodep, 0); $<instp>$ = vmcodep; }
       stats END WHILE { gen_branch(&vmcodep, $<instp>2);
       			vm_target2Cell(vmcodep, $<instp>5[-1]);		}
     | FOR '(' VAR IDENT ';' { insert_local($<sval>3, VAR_INT);		}
     		txpr ';'     { gen_zbranch(&vmcodep, 0);
			        $<instp>$ = vmcodep;			}
		commastats ')'     { $<instp>$ = $<instp>8;		}
	dopart END FOR	      { BB_BOUNDARY; vm_target2Cell(vmcodep,
						$<instp>10[-1]);	}
     | IDENT '=' txpr       { if (var_type($<sval>1) == VAR_INT)
     				gen_storelocalnum(&vmcodep, 
     					var_offset($<sval>1));	
			      else if (var_type($<sval>1) == VAR_STR)
			      	gen_storelocalstr(&vmcodep,
					var_offset($<sval>1));
			      else if (var_type($<sval>1) == VAR_FLOAT)
			      	gen_storelocalflt(&vmcodep,
					var_offset($<sval>1));		}
     | OUTPUT STD_OUT
     	'$' txpr      	    { gen_output(&vmcodep, 1);			}
     | OUTPUT STD_ERR	   
     	'$' txpr	    { gen_output(&vmcodep, 2);			}
     
     | OUTPUT THIS_FILE	
     	'$' txpr	    { gen_output(&vmcodep, 3);			}
     | OUTPUT STD_IN
     	'$' txpr	    { gen_output(&vmcodep, 0);			}
     | INPUT STD_OUT        
     	'$' IDENT	    { gen_input(&vmcodep, 1);			}
     	
     | INPUT STD_ERR
     	'$' IDENT	    { gen_input(&vmcodep, 2);			}
     | INPUT THIS_FILE	   
        '$' IDENT	    { gen_input(&vmcodep, 3);			}
     | INPUT STD_IN	
     	'$' IDENT	    { gen_input(&vmcodep, 0);			}
     | OUTPUT filehandle 
     	'$' txpr	    { gen_output_handle(&vmcodep);		}
     | INPUT  filehandle
     	'$' IDENT	    { gen_input_handle(&vmcodep); 		}
     | txpr		    { gen_drop(&vmcodep);			}
     |;

filehandle : FILE_HANDLE	{ 
	   			  FILE* handle = NULL;
	   			  if ((handle = 
				  get_handle($<handle>1.name) == NULL)) {
					handle = fopen($<handle>1.name,
						  	$<handle>1.mode);
					insert_handle($<handle>1.name, 
							handle);
					gen_litfile(&vmcodep, handle);
				  } else
				         gen_litfile(&vmcodep, handle);
			 					      }

dopart : DO { gen_branch(&vmcodep, 0); $<instp>$ = vmcodep;
       		vm_target2Cell(vmcodep, $<instp>0[-1]); 	        }
	  stats { $$ = $<instp>2;	}
       | { $$ = $<instp>0;		}
       ;
          

elsepart : ELSE { gen_branch(&vmcodep, 0); $<instp>$ = vmcodep;
     	    vm_target2Cell(vmcodep, $<instp>0[-1]); }
            stats { $$ = $<instp>2; }
	 |  { $$ = $<instp>0;	}
	 ;


string : SQ SQ_TXT SQ 		 { gen_litstr(&vmcodep, $<sval>2); }
       | DQ DQ_TXT DQ		 { gen_litstr(&vmcodep, $<sval>2); }
       | TBT TBT_TXT TBT	 { gen_litstr(&vmcodep, $<sval>2); }
       ;

txpr : term '+' term     { gen_add(&vmcodep);     }
     | term '-' term     { gen_sub(&vmcodep);     }
     | term '*' term     { gen_mul(&vmcodep);     }
     | term '&' term     { gen_and(&vmcodep);     }
     | term '%' term	 { gen_rem(&vmcodep);     }
     | term '|' term     { gen_or(&vmcodep);      }
     | term '<' term     { gen_lt(&vmcodep);      }
     | term '>' term	 { gen_gt(&vmcodep);      }
     | term '^' term	 { gen_xor(&vmcodep);     }
     | fterm '+' fterm	 { gen_fadd(&vmcodep);    }
     | fterm '-' fterm	 { gen_fsub(&vmcodep);    }
     | fterm '*' fterm	 { gen_fmul(&vmcodep);	  }
     | fterm '/' fterm	 { gen_fdiv(&vmcodep);	  }
     | fterm POW fterm	 { gen_fpow(&vmcodep);    }
     | term DIV fterm	 { gen_idiv(&vmcodep);    }
     | term AND term	 { gen_land(&vmcodep);    }
     | term OR  term	 { gen_lor(&vmcodep);     }
     | term POW term	 { gen_pow(&vmcodep);	  }
     | term SHR term	 { gen_shr(&vmcodep);	  }
     | term SHL term	 { gen_shl(&vmcodep);	  }
     | term GE  term	 { gen_ge(&vmcodep);	  }
     | term LE  term 	 { gen_le(&vmcodep);	  }
     | term EQ  term	 { gen_eq(&vmcodep);	  }
     | term NE  term	 { gen_ne(&vmcodep);	  }
     | '!' term          { gen_not(&vmcodep);     }
     | '-' term          { gen_neg(&vmcodep);     }
     | term
     | scat
     ;

scat : scat string '+' string           { gen_strcat(&vmcodep);  }
     |;

fterm : FLOATNUM			{ gen_litflt(&vmcodep,
     				          	$<fval>1);          }
     ;

term : '(' txpr ')'
     | IDENT '(' targ ')'	{ gen_call(&vmcodep, 
     					func_addr($<sval>1),
					func_calladjust($<sval>1)); }
     | IDENT			{ int type = var_type($<sval>1);
				  if (type == VAR_INT)
					gen_loadlocalnum(&vmcodep, 
     						var_offset($<sval>1));	  
				  else if (type == VAR_STR)
				  	gen_loadlocalstr(&vmcodep,
						var_offset($<sval>1));
				  else if (type == VAR_FLOAT)
				  	gen_loadlocalflt(&vmcodep,
						var_offset($<sval>1));
								    }
     | NUM			{ gen_litnum(&vmcodep, $<ival>1);   }
     | string
     | fterm
     ;

targ : txpr ',' targ
     | txpr
     ;

call : CALL_PREFIX
     	IDENT '(' args ')'     { body_code = get_symbol($<sval>2);
				 yyparse_body();		}
     | CALL_PREFIX
        IDENT CALL_SUFFIX      { fprintf(yyout, "%s", 
					get_symbol($<sval>2));   }
     ;

exchange : DEF_PREFIX
       EXCHANGE '$' IDENT 
       XCHN_MARK IDENT '\n'     { exchange_symbol($<sval>2, 
       						  $<sval>4);	 }

define : DEF_PREFIX
     	DEFINE '$'
	IDENT CHEVRON 
	quote		       { insert_symbol($<sval>4, 
					$<sval>6);		}
     | DEF_PREFIX
     	DEFEVAL '$'
	IDENT CHEVRON
	quote		       { defeval_insert($<sval>4,
					$<sval>6);		}
     ;

exit : ENGAGE_PREFIX
         EXIT  '\n'	       { exit(EXIT_SUCCESS);		}
     | ENGAGE_PREFIX
         EXIT '$'
	  ARGNUM  '\n'	       { exit($<ival>4);		}
     ;

escape : '\\' ESC_TEXT	      { fputs($<sval>2, yyout);	}
     ;

search : ENGAGE_PREFIX
         SEARCH '$'
	  quote
	  FILEPATH '\n'     {   reg_pattern = $<sval>4;
	  			open_search_close($<sval>5);   }
     | ENGAGE_PREFIX
         SEARCH '$' 
	  quote
	  CURRENT '\n'      { 	reg_pattern = $<sval>4;
	  			yyin_search();			}
     ;

printf : ENGAGE_PREFIX
         PRINTF '$'
	  quote { fmt = $<sval>4; } '(' args ')' 
	  		'\n' { print_formatted(); }
     ;


args :
     | arguments ',' args	
     | arguments
     ;

arguments : ARG_NUM			{ invoke_addarg($<sval>1); }
     | ARG_STR			{ invoke_addarg($<sval>1); }
     | ARG_IDENT		{ invoke_addarg(get_symbol($<sval>1)); }
     ;

token : ENGAGE_PREFIX
     	CHANGETOKEN 
	  '$' ENGAGEPREFIX CHNGVAL { strcpy(&engage_prefix_token[0],
						$<sval>5);		}
      | ENGAGE_PREFIX 
        CHANGETOKEN 
          '$' DEFPREFIX CHNGVAL { strcpy(&define_prefix_token[0],
                                                $<sval>5);              }
      | ENGAGE_PREFIX 
        CHANGETOKEN 
          '$' CALLPREFIX CHNGVAL { strcpy(&call_prefix_token[0],
                                                $<sval>5);              }
      | ENGAGE_PREFIX 
        CHANGETOKEN 
          '$' CALLSUFFIX CHNGVAL { strcpy(&call_suffix_token[0],
                                                $<sval>5);              }
      | ENGAGE_PREFIX 
        CHANGETOKEN 
          '$' QUOTELEFT CHNGVAL { strcpy(&quote_left_token[0],
                                                $<sval>5);              }
      | ENGAGE_PREFIX                   
        CHANGETOKEN   
          '$' QUOTERIGHT CHNGVAL { strcpy(&quote_right_token[0],    
                                                $<sval>5);              }
      | ENGAGE_PREFIX                   
        CHANGETOKEN   
          '$' DELIMLEFT CHNGVAL { strcpy(&delim_left_token[0],    
                                                $<sval>4);              }
      | ENGAGE_PREFIX                   
        CHANGETOKEN   
          '$' DELIMRIGHT CHNGVAL { strcpy(&delim_right_token[0],    
                                                $<sval>4);              }
      | ENGAGE_PREFIX                   
        CHANGETOKEN   
          '$' COMMENTLEFT CHNGVAL { strcpy(&comment_left_token[0],    
                                                $<sval>4);              }
      | ENGAGE_PREFIX                   
        CHANGETOKEN   
          '$' COMMENTRIGHT CHNGVAL { strcpy(&comment_right_token[0],
                                                $<sval>5);              }
      | ENGAGE_PREFIX
 	CHANGETOKEN
 	 '$' TMPLDELIMLEFT CHNGVAL { strcpy(&template_delim_left_token[0],
	   					$<sval>5);		}
      | ENGAGE_PREFIX 
 	CHANGETOKEN
         '$' TMPLDELIMRIGHT CHNGVAL { strcpy(&template_delim_right_token[0],
                                                $<sval>5);              }
      ;

print : ENGAGE_PREFIX
     	PRINT '$' ENVIRON 
		quote  '\n'    { print_env($<sval>5);	}
     | ENGAGE_PREFIX
        PRINT '$' ARGV
	        ARGNUM  '\n'    { print_argv($<ival>5);		}
     ;

translit : ENGAGE_PREFIX
        TRANSLIT '$'
	quote '>'
	quote '&'
	quote '\n'	       { translit($<sval>4,  
					$<sval>6,  
					$<sval>8);		}
     ;

offset : ENGAGE_PREFIX
        OFFSET '$'
	quote '?'
	quote '\n'            { offset($<sval>4, 
				         $<sval>6);	}

     ;

ldir : ENGAGE_PREFIX
        LSDIR '$'
	FILEPATH '\n'          { list_dir($<sval>4);		}
     ;

date : ENGAGE_PREFIX
     	DATETIME '$'
	quote '\n'            { format_time($<sval>4);   }
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

patsub : ENGAGE_PREFIX
       PATSUB '$'
       quote '?'
       quote ':'
       quote '\n'	      { patsub($<sval>4, 
       					$<sval>6, $<sval>8);   }
       ;

substitute : ENGAGE_PREFIX
       SUBSTITUTE '$'
       quote '?'
       quote ':'
       quote '\n'	      { substitute($<sval>4, 
       					$<sval>6, $<sval>8);   }
           ;

ifexec : ENGAGE_PREFIX
     	quote IFEX quote 
     	 '?' quote
	 ':' quote '\n'      { ifelse_execmatch($<sval>2,
					$<sval>4,
					$<sval>6,
					$<sval>8,
					$<cmpval>3);           }
     ;

ifregex : ENGAGE_PREFIX
     	REGEX 	'$' 
	quote  '?'
	quote	':'
	quote	'\n'		{ reg_pattern    = $<sval>2;
				  reg_input      = $<sval>4;
				  reg_matchmsg 	 = $<sval>6;
				  reg_nomatchmsg = $<sval>8;
				  ifelse_regmatch();		 }
     ;

undivert : ENGAGE_PREFIX
     	 UNDIVERT '$' 
	 DIVNUM  '\n'    	{  unswitch_output();	
	 			   unset_divert($<ival>4);       }
     ;

divert : ENGAGE_PREFIX
         DIVERT '$' 
	 DIVNUM '\n'	        { set_divert($<ival>4);
	 			  switch_output(current_divert); }
     ;

dlim : ENGAGE_PREFIX
	EXEC_DELIM '$' quote
	  '|' delimited '\n'    { delim_command = $<sval>4;
	  			  init_delim_stream($<sval>6);
				  exec_delim_command();	         }
     ;



exec : ENGAGE_PREFIX
     	EXEC '$' 
	     quote '\n'	       { exec_command($<sval>4);	 }

     ;

delimited : DLEFT ENCLOSED DRIGHT   { $$ = gc_strdup($<sval>2);       }

quote : QLEFT ENCLOSED QRIGHT   { $$ = gc_strdup($<sval>2);	 }
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
