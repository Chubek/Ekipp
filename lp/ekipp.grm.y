%{
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <math.h>
#include <sysexits.h>
#include <ffi.h>

#include <unistr.h>
#include <unistdio.h>
#include <gc.h>

#include "ekipp.h"
#include "machine.h"

#include "machine-gen.i"

#define TOK_MAX	2

#define BB_BOUNDARY (last_compiled = NULL, block_insert(vmcodep)) 

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

void gen_main_end(void)
{
  gen_call(&vmcodep, func_addr("main"), func_calladjust("main"));
  gen_end(&vmcodep);
  BB_BOUNDARY;
}
%}
%define parse.error detailed
%token ENGAGE_PREFIX CALL_PREFIX CALL_SUFFIX DEF_PREFIX DLEFT DRIGHT QLEFT QRIGHT
%token ENCLOSED ESC_TEXT REGEX ARGNUM
%token TRANSLIT LSDIR CATFILE DATETIME OFFSET INCLUDE PATSUB SUBSTITUTE
%token EXEC EVAL REFLECT DNL LF EXEC_DELIM IFEXEC
%token ARG_NUM ARG_IDENT ARG_STR IDENT
%token DIVERT UNDIVERT
%token EXIT ERROR PRINT PRINTF ENVIRON FILEPATH SEARCH ARGV CURRENT
%token GE LE EQ NE SHR SHL POW IDIV AND OR INCR DECR IFEX CHEVRON XCHN_MARK
%token DIVNUM NUM FLOATNUM
%token DEFEVAL DEFINE EXCHANGE
%token FUNC RETURN VAR ARRAY TYPE ELSE IF DO WHILE FOR END THEN INIT_ASSIGN
%token IMPORT NAMESPACE
%token SQ_TXT DQ_TXT TBT_TXT
%token DELIM_TEMPLATE_BEGIN DELIM_TEMPLATE_END
%token STD_IN STD_OUT STD_ERR THIS_FILE FILE_HANDLE INPUT OUTPUT
%token COMMENTLEFT DELIMLEFT TMPLDELIMLEFT QUOTELEFT
%token COMMENTRIGHT DELIMRIGHT TMPLDELIMRIGHT QUOTERIGHT
%token ENGAGEPREFIX CALLPREFIX DEFPREFIX CALLSUFFIX CHANGETOKEN CHNGVAL
%token TEMPLATE_DELIM_BEGIN TEMPLATE_DELIM_END
%token HOOK_LIB HOOK_SYM EXTERN_CALL INTOSYM
%token BASE10 BASE8 BASE16 BASE2
%token STR2FLT FLT2STR FLT2NUM NUM2FLT NUM2STR STR2NUM CONV

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

%type <sval>  delimited
%type <ival>  expr
%type <instp> elsepart
%type <instp> dopart
%type <sval>  quote
%type <tval>  txpr
%type <tval>  term
%type <ival>  base

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


template : TEMPLATE_DELIM_BEGIN { init_vm(); }
	 	program TEMPLATE_DELIM_END { execute_vm(0, 0);	}
	 ;

program : program function
	|;



function : FUNC IDENT   { locals = 0; nonparams = 0; } '(' params ')'
	 ':' TYPE '='
	 vars		{ insert_func($<sval>2, vmcodep, 
	 			locals, nonparams, $<tval>8);	}
	 stats RETURN txpr ';'
	 END FUNC ';'	{ 
	 	   if ($<tval>8 == VAR_INT)	
				gen_returnnum(&vmcodep, -adjust(locals));
		   else if ($<tval>8 == VAR_STR)
		        	gen_returnstr(&vmcodep, -adjust(locals));
		   else if ($<tval>8 == VAR_FLOAT)
				gen_returnflt(&vmcodep, -adjust(locals));
		}
	 ;

params : IDENT ':' TYPE ',' { insert_local($<sval>1, 
       				$<tval>3); } params
       | IDENT ':' TYPE	    { insert_local($<sval>1, 
       				$<tval>3); }
       |;

vars : vars VAR IDENT ':' TYPE ';' { insert_local($<sval>3,
     						   $<tval>5);
     					nonparams++;		        }
     | vars ARRAY '[' txpr 
     	']' IDENT 
	':' TYPE ';' {  if ($4 == VAR_INT)
				gen_storelocalnum(&vmcodep, 
						var_offset(size_id($<sval>6)));
			else {
				fputs("Index for array initialization must be evaluated, or be, an integer\n", stderr);
				exit(EX_USAGE);
			}
			insert_local($<sval>6, $<tval>7 | VAR_ARRAY);
				nonparams++;
						   			}
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
     | IDENT  { if (!var_isarray($<sval>1) 
     				  || !(var_type($<sval>1) & VAR_INT)) {
				  	fputs("Array must be of integer tpye to accept integer array literal\n", stderr);
					exit(EX_USAGE);	  
				  }
				    gen_loadlocalptr(&vmcodep, 
				       var_offset($<sval>1));
				    gen_loadlocalnum(&vmcodep,
				       var_offset(size_id($<sval>1)));
			} '=' numarrlit
     | IDENT  { if (!var_isarray($<sval>1) 
      				  || !(var_type($<sval>1) & VAR_FLOAT)) {
				  	fputs("Array must be of float tpye to accept float array literal\n", stderr);
					exit(EX_USAGE);	  
				  }
				    gen_loadlocalptr(&vmcodep, 
				       var_offset($<sval>1));
				    gen_loadlocalnum(&vmcodep,
				       var_offset(size_id($<sval>1)));
			} '=' fltarrlit
     | IDENT  { if (!var_isarray($<sval>1) 
     				  || !(var_type($<sval>1) & VAR_STR)) {
				  	fputs("Array must be of string tpye to accept string array literal\n", stderr);
					exit(EX_USAGE);	  
				  }
				    gen_loadlocalptr(&vmcodep, 
				       var_offset($<sval>1));
				    gen_loadlocalnum(&vmcodep,
				       var_offset(size_id($<sval>1)));
			} '=' strarrlit
     | IDENT INIT_ASSIGN txpr { insert_local($<sval>1, $<tval>3);	}
     | OUTPUT STD_OUT
     	'$' printtxt   	    { gen_output(&vmcodep, 1);			}
     | OUTPUT STD_ERR	   
     	'$' printtxt	    { gen_output(&vmcodep, 2);			}
     
     | OUTPUT THIS_FILE	
     	'$' printtxt	    { gen_output(&vmcodep, 3);			}
     | OUTPUT STD_IN
     	'$' printtxt	    { gen_output(&vmcodep, 0);			}
     | INPUT STD_OUT        
     	'$' IDENT	    { gen_input(&vmcodep, 1);			}
     	
     | INPUT STD_ERR
     	'$' IDENT	    { gen_input(&vmcodep, 2);			}
     | INPUT THIS_FILE	   
        '$' IDENT	    { gen_input(&vmcodep, 3);			}
     | INPUT STD_IN	
     	'$' IDENT	    { gen_input(&vmcodep, 0);			}
     | OUTPUT filehandle 
     	'$' printtxt	    { gen_output_handle(&vmcodep);		}
     | INPUT  filehandle
     	'$' IDENT	    { gen_input_handle(&vmcodep); 		}
     | txpr		    { gen_drop(&vmcodep);			}
     | IMPORT NAMESPACE     { resolve_namespace($<sval>2); 		}
     | HOOK_LIB 
     	 IDENT '$'
     	    filehandlestr   { gen_libopen(&vmcodep);
				insert_local($<sval>2, VAR_HANDLE);
				gen_storelocalstr(&vmcodep, 
					var_offset($<sval>2));
				nonparams++;				}
     | HOOK_SYM
     	 IDENT INTOSYM 
	 	IDENT	    { 	gen_loadlocalptr(&vmcodep, 
					var_offset($<sval>2));
				gen_litstr(&vmcodep, $<sval>4);
				gen_libsym(&vmcodep);
				insert_local($<sval>4, VAR_SYMBOL);
				gen_storelocalstr(&vmcodep, 
						var_offset($<sval>4));
				nonparams++;				}
     | EXTERN_CALL
     	 IDENT '(' { zero_out_externif();  } 
	 externarg ')' 
	 ':' TYPE INTOSYM IDENT { if (var_type($<sval>2) != VAR_SYMBOL) {
				   fputs("Variable must be an extenral symbol" , stderr);
				  exit(EX_USAGE);
				}
				gen_loadlocalptr(&vmcodep,
						var_offset($<sval>2));
				if ($<tval>8 == VAR_STR) {
					ExternCall->retrtype = ffi_type_pointer;
					gen_excallstr(&vmcodep);
				}
				else if ($<tval>8 == VAR_INT) {
					ExternCall->retrtype = ffi_type_sint64;
					gen_excallnum(&vmcodep);
				}
				else if ($<tval>8 == VAR_FLOAT) {
					ExternCall->retrtype = ffi_type_longdouble;
					gen_excallflt(&vmcodep);
				} 
				insert_local($<sval>10, $<tval>8);
				gen_storelocalstr(&vmcodep, 
				              var_offset($<sval>10));
				nonparams++;
									}
     | CONV convert
     |;


printtxt : IDENT		{ int type = var_type($<sval>1);
	 			   if (type == VAR_STR)
				   	gen_loadlocalstr(&vmcodep, 
						var_offset($<sval>1));
				   else {
				   	fputs("Variable sent to print must be a string\n", stderr);
					exit(EX_USAGE);
					}				}
	 | SQ_TXT		{ gen_litstr(&vmcodep, $<sval>1);	}
	 | DQ_TXT		{ gen_litstr(&vmcodep, $<sval>1);	}
	 | TBT_TXT		{ gen_litstr(&vmcodep, $<sval>1);	}
	 | txpr			{ if ($1 != VAR_STR) {
					fputs("Expression sent to print does not evaluate to an string\n", stderr);
					exit(EX_USAGE);
				}
									}
externarg : txpr ',' externarg  { if ($1 == VAR_INT)
	  				gen_libargnum(&vmcodep);
				  else if ($1 == VAR_STR)
					gen_libargstr(&vmcodep);
				  else if ($1 == VAR_FLOAT)
				  	gen_libargflt(&vmcodep);	}
	  | txpr		{ if ($1 == VAR_INT)
                                        gen_libargnum(&vmcodep);
                                  else if ($1 == VAR_STR)
                                        gen_libargstr(&vmcodep);
                                  else if ($1 == VAR_FLOAT)
                                        gen_libargflt(&vmcodep);        }
	  ;

filehandlestr : FILE_HANDLE     { gen_litstr(&vmcodep, $<handle>1.name); }

filehandle : FILE_HANDLE	{ 
	   			  FILE* handle = NULL;
		  if ((handle = get_handle($<handle>1.name)) == NULL) {
		        handle = fopen($<handle>1.name,
				  	$<handle>1.mode);
			insert_handle($<handle>1.name, 
					handle);
			gen_litfile(&vmcodep, handle);
		  } else 
		        gen_litfile(&vmcodep, handle);			}

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

fltarrlit : '[' fltarrlit ']'
	    | fltarrlit ',' FLOATNUM { gen_arrlitflt(&vmcodep, 
	    					$<fval>3);		}
	    | FLOATNUM		       { gen_arrlitflt(&vmcodep,
	    					$<fval>1);		}
	    |;

strarrlit : '[' strarrlit ']'
	  | strarrlit ',' DQ_TXT  { gen_arrlitstr(&vmcodep, $<sval>3);	}
	  | DQ_TXT		 { gen_arrlitstr(&vmcodep, $<sval>1);	}
 	  | strarrlit ',' SQ_TXT  { gen_arrlitstr(&vmcodep, $<sval>3);	}
	  | SQ_TXT		 { gen_arrlitstr(&vmcodep, $<sval>1);	}
	  | strarrlit ',' TBT_TXT { gen_arrlitstr(&vmcodep, $<sval>3);	}
          | TBT_TXT		 { gen_arrlitstr(&vmcodep, $<sval>1);	}
	  |;


numarrlit : '[' numarrlit ']'
	  | numarrlit ',' NUM	{ gen_arrlitnum(&vmcodep, $<ival>3);	}
	  | NUM			{ gen_arrlitnum(&vmcodep, $<ival>1);	}
	  |;

txpr : term '+' term     { $$ = $<tval>1;
     			   if ($1 == VAR_INT && $3 == VAR_INT)
     				gen_add(&vmcodep);
			   else if ($1 == VAR_FLOAT)
			   	gen_fadd(&vmcodep);
			   else if ($1 == VAR_STR && $3 == VAR_STR)
			   	gen_strcat(&vmcodep);		}
     | term '-' term     { $$ = $<tval>1;
     			   if ($1 == VAR_INT && $3 == VAR_INT)
     				gen_sub(&vmcodep);
			   else if ($1 == VAR_FLOAT)
			   	gen_fsub(&vmcodep);		}
     | term '*' term     { $$ = $<tval>1;
     			   if ($1 == VAR_INT && $3 == VAR_INT)
	                         gen_mul(&vmcodep);   
			   else if ($1 == VAR_FLOAT)
			   	 gen_fmul(&vmcodep);		}
     | term '&' term     { gen_and(&vmcodep); $$ = $<tval>1;    }
     | term '%' term	 { gen_rem(&vmcodep); $$ = $<tval>1;    }
     | term '|' term     { gen_or(&vmcodep);  $$ = $<tval>1;    }
     | term '<' term     { gen_lt(&vmcodep);  $$ = $<tval>1;    }
     | term '>' term	 { gen_gt(&vmcodep);  $$ = $<tval>1;    }
     | term '^' term	 { gen_xor(&vmcodep); $$ = $<tval>1;    }
     | term IDIV term	 { gen_idiv(&vmcodep); $$ = $<tval>1;	}
     | term AND term	 { gen_land(&vmcodep); $$ = $<tval>1;  }
     | term OR  term	 { gen_lor(&vmcodep);  $$ = $<tval>1;  	}
     | term POW term	 { gen_pow(&vmcodep);  $$ = $<tval>1;  	}
     | term SHR term	 { gen_shr(&vmcodep);  $$ = $<tval>1;    }
     | term SHL term	 { gen_shl(&vmcodep);  $$ = $<tval>1;    }
     | term GE  term	 { gen_ge(&vmcodep);   $$ = $<tval>1;    }
     | term LE  term 	 { gen_le(&vmcodep);   $$ = $<tval>1;    }
     | term EQ  term	 { gen_eq(&vmcodep);   $$ = $<tval>1;    }
     | term NE  term	 { gen_ne(&vmcodep);   $$ = $<tval>1;    }
     | '!' term          { gen_not(&vmcodep);  $$ = $<tval>1;    }
     | '-' term          { gen_neg(&vmcodep);  $$ = $<tval>1;    }
     | term		 { $$ = $<tval>1;			 }
     ;


convert : '(' NUM2STR ')' txpr 
			  base { gen_litnum(&vmcodep, $5); } '$' 
			  IDENT { gen_num2str(&vmcodep); 
			  		gen_storelocalstr(&vmcodep, 
					var_offset($<sval>8));   	}
	| '(' STR2NUM ')' txpr 
			  base { gen_litnum(&vmcodep, $5); } '$' 
			  IDENT { gen_str2num(&vmcodep); 
			  	  gen_storelocalnum(&vmcodep, 
				  var_offset($<sval>8)); 		 }
	| '(' FLT2STR ')' txpr '$' IDENT { gen_flt2str(&vmcodep); 
					    gen_storelocalstr(&vmcodep, 
					    var_offset($<sval>6));	 }
	| '(' STR2FLT ')' txpr '$' IDENT { gen_str2flt(&vmcodep);
					    gen_storelocalflt(&vmcodep,
					    var_offset($<sval>6));  }
	| '(' FLT2NUM ')' txpr '$' IDENT { gen_flt2num(&vmcodep);
					    gen_storelocalnum(&vmcodep,
					    var_offset($<sval>6));   }
	| '(' NUM2FLT ')' txpr '$' IDENT { gen_num2flt(&vmcodep);
					     gen_storelocalflt(&vmcodep,
					     var_offset($<sval>6));  }
	|;

base : BASE10	{ $$ = 10; }
     | BASE16 	{ $$ = 16; }
     | BASE8	{ $$ = 8;  }
     | BASE2	{ $$ = 2;  }
     ;

term : '(' txpr ')'		{ $$ = 0; }
     | IDENT '[' txpr ']'	{ if (!var_isarray($<sval>1)) {
					fputs("Variable is not an array\n", stderr);
					exit(EX_USAGE);
				  }
     				  gen_loadlocalptr(&vmcodep,
     					var_offset($<sval>1));
				  if (var_type($<sval>1) & VAR_FLOAT)
					gen_accessflt(&vmcodep);
				  else if (var_type($<sval>1) & VAR_INT)
				  	gen_accessnum(&vmcodep);
				  else if (var_type($<sval>1) & VAR_STR) {
				        gen_accessstr(&vmcodep);
				  }
				  $$ = var_type($<sval>1);
									}
     | IDENT '(' targ ')'	{ gen_call(&vmcodep, 
     					func_addr($<sval>1),
					func_calladjust($<sval>1));
					$$ = func_retrtype($<sval>1);   }
     | IDENT			{ int type = var_type($<sval>1);
     				  $$ = type;
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
     | SQ_TXT                  { gen_litstr(&vmcodep, $<sval>1);
     					$$ = VAR_STR;			}
     | DQ_TXT                  { gen_litstr(&vmcodep, $<sval>1); 
     					$$ = VAR_STR;			}
     | TBT_TXT                 { gen_litstr(&vmcodep, $<sval>1); 
     					$$ = VAR_STR;			}
     | NUM		       { gen_litnum(&vmcodep, $<ival>1);
     					$$ = VAR_INT;			}
     | FLOATNUM		       { gen_litflt(&vmcodep, $<fval>1); 
     					$$ = VAR_FLOAT;			}
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
       quote '\n'	      { subst($<sval>4, 
       				   $<sval>6, $<sval>8);  	}
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
