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

extern void  yyerror(char*);
extern FILE* yyout;

static inline int yylex(void);
static uint8_t uc;

uint8_t* body_code = NULL;
%}

%union {
	int		 ival;
	uint8_t*	 wval;
	uint8_t		 cval;
}


%token ARGNO BODY_TEXT ESC_TEXT
%token PUNCT JOIN_SPACE JOIN_COMMA
%%

body :
     | '\n'		{ fputc('\n', yyout);		      }
     | text body
     ;


text : argn
     | BODY_TEXT 	{ fputc($<cval>1, yyout); 	      }
     | ESC_TEXT		{ fputc($<cval>1, yyout);	      }
     ;

argn : '#' ARGNO	{ invoke_printarg($<ival>2);
     				   fputc(uc, yyout);          }
     | JOIN_SPACE	{ invoke_printargs(" ");	      }
     | JOIN_COMMA	{ invoke_printargs(", ");	      }
     ;


%%

#define STATE_INIT	 1
#define STATE_ARGN 	 2
#define STATE_BODY 	 3

#define MAX_NUM 	 32

static int state = STATE_INIT;

static char escape_map[SCHAR_MAX] = {
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0x27, 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 63, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0x0b, 
	0, 0, 0, 0, 0x07, 0x08, 
	0, 0, 0x1b, 0xc, 0, 0, 0, 
	0, 0, 0, 0, 0xa, 0, 0, 0, 0xd,
	0x20, 0x9, 0, 0xb, 0, 0, 0, 
	0, 0, 0, 0, 0,
};

static inline int yylex(void) {
	while ((uc = *body_code++)) {
		switch (uc) {
			case '#':
				if (state != STATE_ARGN 
					&& isdigit(*body_code)) {
					state = STATE_ARGN;
					return '#';
				} else if (state == STATE_BODY) {
					yylval.cval = uc;
					return BODY_TEXT;
				} else if (*body_code == '@') {
					body_code++;
					return JOIN_SPACE;
				} else if (*body_code == '*') {
					body_code++;
					return JOIN_COMMA;
				}
				break;
			case '\n':
				return '\n';
			case '\\':
				if (escape_map[*body_code]) {
					yylval.cval = 
						escape_map[*body_code++];
					return ESC_TEXT;
				} else {
					yylval.cval = uc;
					return BODY_TEXT;
				}
				break;
			case '0':
			case '1':
			case '2':
			case '3':
			case '4':
			case '5':
			case '6':
			case '7':
			case '8':
			case '9':
				if (state != STATE_ARGN) {
					yylval.cval = uc;
					return BODY_TEXT;
				} else {
					char num[MAX_NUM + 1] = {0};
					int i = 0;
					body_code--;
					while (isdigit((uc = *body_code++))
						&& i < MAX_NUM)
						num[i++] = uc;
					yylval.ival  = atoi(&num[0]);
					return ARGNO;
				}
				break;
			case '\0':
				return YYEOF;
			default:
				state 		= STATE_BODY;
				yylval.cval 	= uc; 
				return BODY_TEXT;

		
		}
	}
}
