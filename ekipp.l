%{

#include <stdio.h>
#include <wchar.h>
#include <stdlib.h>
#include <string.h>

int 		yylex(void);
void		yyerr(char* error);
FILE*		yyin;

#include "yy.tab.h"

%}

Decimal		[+-][1-9][0-9]*;
Hexal		[0xX][a-fA-F0-9]+
Octal		[0oO][0-7]+
Binary		[0bB][0-1]+
Ident		[a-zA-Z\_][a-zA-Z\_0-9]*

%%
	#include "yylex.i"

{Decimal}	{ yylval.ival = 
                     strtoll(yytext, NULL, 10); return NUM;      }
{Hexal}		{ yylval.ival = 
                     strtoll(&yytext[2], NULL, 16); return NUM;  }
{Octala}	{ yylval.ival = 
                     strtoll(&yytext[2], NULL, 8); return NUM;   }
{Binary}	{ yylval.ival = 
                     strtoll(&yytext[2], NULL, 2); return NUM; 	 }

{Ident}		{ yylval.wval = yytext;  return IDENT;		 }

[0-9]		{ yylval.ival = atoi(&yytext[0]); return DIVNUM; }

[0-9]+		{ yylval.ival = atoi(&yytext[0]); return ARGNUM; }

"engage"	return ENGAGE;
"dnl"		return DNL;
"exec-if"	return EXECIF;
"match-if"	return MATCHIF;

"lsdir"		return LSDIR;
"translit"	return TRANSLIT;
"catfile"	return CATFILE;
"suboffset"	return SUBOFFS;
"datetime"	return DATETIME;

"divert"	return DIVERT;
"undivert"	return UNDIVERT;

"exec"		return EXEC;
"eval"		return EVAL;

"pop"		return POP;
"push"		return PUSH;

"current"	return CURRENT;
"sigils"	return SIGILS;
"left-tokens"	return LEFT_TOKENS;
"right-tokens"	return RIGHT_TOKENS;

">="		return GE;
"<="		return LE;
"=="		return EQ;
"!="		return NE;
">>"		return SHR;
"<<"		return SHL;
"**"		return POW;
"++"		return INCR;
"--"		return DECR;




