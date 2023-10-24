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

body : BYPASS			{ OUTPUT($<wval>1);		 }
     | QUOTED
     | eval
     | divert
     | auxil
     | exec
     | argnum
     ;



auxset : AUXIL_SIGIL
           QUOTED		{ set_auxil(&auxil_prim, $<wval>2); }
       | auxset ','
	    QUOTED              { set_auxil(&auxil_sec, $<wval>3);  }
       | auxset ','
	   QUOTED ',' QUOTED   {
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
          EXEC SHELL_CMD	{ 
	  				exec_cmd = $<wval>3;
					exec_command();
				}
     ;

eval : ENGAGE_SIGIL
          EVAL expr		{ fprintf(output, "%ld", $<ival>3); }
     ;

argnum : ARGNUM_SIGIL ARGNUM    { invoke_printarg($<ival>2);        }
       | ARGNUM_SIGIL QUOTED    { invoke_printargs($<wval>2);       }
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






