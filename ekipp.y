%{

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include "ekipp.h"

extern  FILE* output;
int 	yylex(void);
FILE* 	yyin;
%}

%token

%%

searchfile: searchset ','
	       SQUOTED		{ open_search_close($<sval>2);  }
	  | searchset ','
	       CURRENT          { yyin_search();		}
	  ;

searchset : SEARCH_SIGIL
	      SQUOTED		{ reg_pattern = $<sval>2;	}
	  ;

ifexec : COND_SIGIL
            SQUOTED
	    WQUOTED
	    WQUOTED
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
         			

undivert : ENGAGE_SIGIL
	     UNDIVERT DIVNUM    {      
	                                unset_divert($<ival>3);
					unswitch_output();
				}
	 ;

divert : ENAGE_SIGIL
           DIVERT DIVNUM        {
	   				set_divert($<ival>3);
					switch_output(current_divert);
				}
       ;

exec : ENGAGE_SIGIL 
          EXEC SQUOTED	{ 
	  				exec_cmd = $<wval>3;
					exec_command();
				}
     ;

eval : ENGAGE_SIGIL
          EVAL expr		{ fprintf(output, "%ld", $<ival>3); }
     ;

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






