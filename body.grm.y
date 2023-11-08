%{
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <ctype.h>
#include <limits.h>

#include <gc.h>

#include "ekipp.h"
#include "body.tab.h"

#define yyparse 	yyparse_body
#define yylval		yylval_body
#define yydebug		yydebug_body
#define yynerrs		yynerrs_body
#define yychar		yychar_body

static inline int yylex(void);
extern void yyerror(char*);


extern FILE* yyout;
uint8_t*     body_code = NULL;
%}

%union {
	int		 ival;
	uint8_t*	 wval;
	uint8_t		 cval;
}


%token ARGNO BODY_TEXT ESC_TEXT
%token JOIN_SPACE JOIN_COMMA
%%

body :
     | '\n'		{ fputc('\n', yyout);		       }
     | text body
     ;


text : argn
     | BODY_TEXT	{ fputc($<cval>1, yyout);	       }
     | ESC_TEXT		{ fputc($<cval>1, yyout);	       }
     ;

argn : ARGNO		{ invoke_printarg($<ival>1);           }
     | '[' ARGNO 
     	   ARGNO ']'	{ invoke_printrng($<ival>1, $<ival>3); }
     | JOIN_SPACE	{ invoke_printargs(" ");	       }
     | JOIN_COMMA	{ invoke_printargs(", ");	       }
     ;


%%


#include "re2c.gen.c"
