%{
#include <stdio.h>
#include <wchar.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

int 		yylex(void);
void		yyerror(char* err);
FILE*		yyin;

extern FILE*	output;

#include "ekipp.h"
#include "yy.tab.h"
%}

Decimal		[+-][1-9][0-9]*
Hexal		[0xX][a-fA-F0-9]+
Octal		[0oO][0-7]+
Binary		[0bB][0-1]+
Ident		[a-zA-Z\_][a-zA-Z\_0-9]*
%%
	#include "yylex.i"

{Decimal}	{ yylval.ival = strtoll(yytext, NULL, 10); 
				return NUM;  }
{Hexal}		{ yylval.ival = strtoll(&yytext[2], NULL, 16); 
				return NUM;  }
{Octal}		{ yylval.ival = strtoll(&yytext[2], NULL, 8); 
				return NUM;   }
{Binary}	{ yylval.ival = strtoll(&yytext[2], NULL, 2); 
				return NUM;   }
[0-9]		{ yylval.ival = atoi(&yytext[0]); 
				return DIVNUM; }
[0-9]+		{ yylval.ival = atoi(&yytext[0]); 
				return ARGNUM; }

engage		return ENGAGE;
dnl		return DNL;
exec-if		return EXECIF;
match-if	return MATCHIF;

lsdir		return LSDIR;
translit	return TRANSLIT;
catfile		return CATFILE;
suboffset	return SUBOFFS;
datetime	return DATETIME;

divert		return DIVERT;
undivert	return UNDIVERT;

exec		return EXEC;
eval		return EVAL;

pop		return POP;
push		return PUSH;

define		return DEFINE;
undef		return UNDEF;

reflect		return REFLECT;
current		return CURRENT;
sigils		return SIGILS;
left-tokens	return LEFT_TOKENS;
right-tokens	return RIGHT_TOKENS;

exit		return EXIT;
error		return ERROR;
print		return PRINT;
environ		return ENVIRON;
formatted	return FORMATTED;
sysargs		return SYSARGS;

>=		return GE;
\<=		return LE;
==		return EQ;
!=		return NE;
>>		return SHR;
\<<		return SHL;
\*\*		return POW;
\+\+		return INCR;
--		return DECR;

[\r\n]+		return NEWLINE;

\x5c		return ESCAPE;

[\'][a-z][\']	{ yylval.cval = yytext[1]; return ASCII; }

{Ident}		{ yylval.wval = wcsdup((wchar_t*)&yytext);  
				return IDENT; }

[^,]{1,255}	{ yylval.wval = wcsdup((wchar_t*)&yytext[0]);
				return ARGUMENT;	  }

.+		ECHO;

%%

void yyerror(char* err) {
	fputs(err, stderr);
}
