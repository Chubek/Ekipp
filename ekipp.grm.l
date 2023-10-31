%{
#include <stdio.h>
#include <wchar.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <limits.h>

#include <gc.h>

int 		yylex(void);
int		yywrap(void);
void		yyerror(const char* err);
FILE*		yyin;

extern char	input_files[FILENAME_MAX][MAX_INPUT];
static int	input_idx = 0;

extern FILE*	output;
extern wchar_t* gc_wcsdup(wchar_t*);
extern char*	gc_strdup(char*);

#include "ekipp.h"
#include "yy.tab.h"
%}

Decimal		[0-9]+
Hexal		[0xX][a-fA-F0-9]+
Octal		[0oO][0-7]+
Binary		[0bB][0-1]+
Ident		[a-zA-Z\_][a-zA-Z\_0-9]*

%x ESC
%x ENG
%x REG
%x ARG
%x INB
%x MOD
%x EVL
%%
	#include "yylex.i"

<INITIAL>[ \t]	    		   ECHO;
<ESC,ENG,REG,ARG,INB,MOD,EVL>[ \t] {};
<*><<EOF>>	  { yyterminate();   }
<EVL,ENG,MOD>[;]  { BEGIN(INITIAL); return *yytext;  }

<EVL>{Decimal}	 { yylval.ival = strtoll(yytext, NULL, 10); 
				return NUM;    }
<EVL>{Hexal}	 { yylval.ival = strtoll(&yytext[2], NULL, 16); 
				return NUM;    }
<EVL>{Octal}	 { yylval.ival = strtoll(&yytext[2], NULL, 8); 
				return NUM;    }
<EVL>{Binary}	 { yylval.ival = strtoll(&yytext[2], NULL, 2); 
				return NUM;    }
<ENG>[0-9]	 { yylval.ival = atoi(&yytext[5]); 
				return DIVNUM; }
<ENG>[0-9]+      { yylval.ival = atoi(&yytext[5]); 
				return ARGNUM; }
<ENG>engage	return ENGAGE;
<ENG>dnl	return DNL;
<ENG>delim	return DELIM;
<ENG>comment	return COMMENT;
<ENG>quote	return QUOTE;

<ENG>lsdir	return LSDIR;
<ENG>translit	return TRANSLIT;
<ENG>catfile	return CATFILE;
<ENG>offset	return OFFSET;
<ENG>datetime	return DATETIME;

<ENG>divert	return DIVERT;
<ENG>undivert	return UNDIVERT;

<ENG>exec	return EXEC;
<ENG>eval	{ BEGIN(EVL); return EVAL; }

<ENG>push	return PUSH;
<ENG>pop	return POP;

<ENG>define	return DEFINE;
<ENG>undef	return UNDEF;

<ENG>reflect	return REFLECT;
<ENG>current	return CURRENT;

<ENG>exit	return EXIT;
<ENG>error	return ERROR;
<ENG>print	return PRINT;
<ENG>printf	return PRINTF;
<ENG>mode	{ BEGIN(MOD); return MODE; }
<ENG>argv	return ARGV;

<ENG>include	return INCLUDE;

<EVL>>=		return GE;
<EVL>\<=	return LE;
<EVL>==		return EQ;
<EVL>!=		return NE;
<EVL>>>		return SHR;
<EVL>\<<	return SHL;
<EVL>\*\*	return POW;
<EVL>\+\+	return INCR;
<EVL>\-\-	return DECR;

<EVL>[\*\+\-\%$]  return *yytext;

[\r\n]+		ECHO;

<ENG>[$<>?:()]   return *yytext;
<ENG>[\n\r]	 { ECHO; BEGIN(INITIAL); }


<INITIAL,ENG>[/]	{ BEGIN(REG); }

<INITIAL,ENG>\\ 	{ BEGIN(ESC); }

<REG>[^\/]+	{ yylval.sval = &yytext[0]; return REGEX; }
<REG>[\/]	    { BEGIN(INITIAL); }

<ESC>.+	       return ESC_TEXT;
<ESC>[\n\r]+   { BEGIN(INITIAL); }

<ENG>{Ident}		{ yylval.wval = gc_wcsdup((wchar_t*)&yytext[0]);
				BEGIN(ARG); return IDENT;    }

<MOD>[$]		return *yytext;
<MOD>[^a-zA-Z]{1,8}   { BEGIN(INITIAL); return VTOK; }

<ENG>[0-9a-zA-Z_/-]{1,255}	{ yylval.sval = gc_strdup(&yytext[0]);
					return FILEPATH; }
<ARG>[^,^)^(^\n]+	{ yylval.wval = gc_wcsdup((wchar_t*)&yytext[0]);
					return ARGUMENT; }
<ARG>[()]	return *yytext;
<ARG>,		BEGIN(INB);
<INB>[^)]	BEGIN(ARG);
<INB>[)]	BEGIN(ENG);

<INITIAL>.+	ECHO;
<INITIAL>[\n]	ECHO;
%%

void yyerror(const char* err) {
	fputs(err, stderr);
}

int yywrap(void) {
	if (input_idx == MAX_INPUT - 1 || !input_files[input_idx + 1][0])
		return 1;
	else {
		if (yyin) 
			fclose(yyin);
		yyin = fopen(input_files[input_idx++], "r");
		return 0;
	}
}
