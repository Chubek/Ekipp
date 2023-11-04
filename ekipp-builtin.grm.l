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
FILE*		yyout;
FILE*		yyin;

extern char	input_files[FILENAME_MAX][MAX_INPUT];
static int	input_idx = 0;


#include "ekipp.h"
#include "yy.tab.h"
%}

Decimal		[0-9]+
Hexal		[0xX][a-fA-F0-9]+
Octal		[0oO][0-7]+
Binary		[0bB][0-1]+
Ident		[a-zA-Z\_][a-zA-Z\_0-9]*
LimOpen		<==
LimClose	==>

%x ESC
%x ENG
%x REG
%x ARG
%x INB
%x EVL
%x DLM1
%x DLM2
%x QUO
%x COM
%x PTH
%x DEF
%s DIV1
%s DIV2
%%
	fflush(yyout);
<*>\/\*	               BEGIN(COM);
<ENG>::	               BEGIN(PTH);
<DIV1>[$]	       return *yytext;
<DIV1>[\n]           { BEGIN(DIV2);    return *yytext; }
<INITIAL,DIV2>^"#! " { BEGIN(ENG);     return ENGAGE_PREFIX; }
<ENG,EVL>[\n]+       { BEGIN(INITIAL); return *yytext;   }

<INITIAL>"@!"	     { BEGIN(DEF); return DEFINE_PREFIX; }
<DEF>[^@!]+\n\n	     { yylval.wval = gc_mbsdup(&yytext[0]); 
			BEGIN(INITIAL); return DEFINE_TEXT;}

<ENG>`	           BEGIN(QUO);
<ENG>[$?:]       return *yytext;
<ENG>[|]         { BEGIN(DLM1); return *yytext; }
<DLM1>{LimOpen}    BEGIN(DLM2);

<*><<EOF>>	  { yyterminate();   }

<COM>[^\*\/]  REJECT;
<COM>\*\/     BEGIN(INITIAL);

<DLM2>[^=>]+        { yylval.wval = gc_mbsdup(&yytext[0]);
			return DELIMITED;   }
<DLM2>{LimClose}      BEGIN(INITIAL);

<QUO>[^`]+  { yylval.qval.wval = gc_mbsdup(&yytext[0]);
	      yylval.qval.sval = gc_strdup(&yytext[0]);
	      return QUOTED;
	    }
<QUO>`	      BEGIN(ENG);

<DIV2>.   { fputc(*yytext, yyout); }
<DIV2>\n  { fputc(*yytext, yyout); }

<EVL,ENG>[$]        return *yytext;
<EVL>[\*\+\-\%<>]   return *yytext;

<INITIAL>[ \t]	  ECHO;
<ESC,DIV1,ENG,REG,ARG,INB,EVL>[ \t] {};

<ENG>[(]	 { BEGIN(ARG); return *yytext; }
<ARG>[,$]	   return *yytext;
<ARG>[)]         { BEGIN(ENG); return *yytext; }
<ARG>{Decimal}  |
   {Hexal}	|
   {Octal}      |
   {Binary}	 { yylval.wval = gc_mbsdup(&yytext[0]);
   				return ARG_NUM;         }
<ARG>{Ident}	 { yylval.wval = gc_mbsdup(&yytext[0]); 
				return ARG_IDENT;       }
<ARG>[^$^(^)^,]+ { yylval.wval = gc_mbsdup(&yytext[0]);
				return ARG_STR;         }


<EVL>{Decimal}	 { yylval.ival = strtoll(yytext, NULL, 10); 
				return NUM;    }
<EVL>{Hexal}	 { yylval.ival = strtoll(&yytext[2], NULL, 16); 
				return NUM;    }
<EVL>{Octal}	 { yylval.ival = strtoll(&yytext[2], NULL, 8); 
				return NUM;    }
<EVL>{Binary}	 { yylval.ival = strtoll(&yytext[2], NULL, 2); 
				return NUM;    }
<DIV1>[\-]?[0-9] { yylval.ival = atoi(&yytext[0]); 
				return DIVNUM; }
<ENG>[0-9]+	 { yylval.ival = atoi(&yytext[0]);
				return ARGNUM; }
<INITIAL>.    ECHO;

<INITIAL>\n   { ECHO; return *yytext; }


<ENG>lsdir	return LSDIR;
<ENG>translit	return TRANSLIT;
<ENG>catfile	return CATFILE;
<ENG>offset	return OFFSET;
<ENG>datetime	return DATETIME;

<ENG>divert     { BEGIN(DIV1); return DIVERT;   }
<ENG>undivert	{ BEGIN(DIV1); return UNDIVERT; }

<ENG>exec	return EXEC;
<ENG>delimexec  return EXEC_DELIM;
<ENG>eval	{ BEGIN(EVL); return EVAL;   }

<ENG>reflect	return REFLECT;
<ENG>current	return CURRENT;

<ENG>exit	return EXIT;
<ENG>error	return ERROR;
<ENG>print	return PRINT;
<ENG>printf	return PRINTF;
<ENG>argv	return ARGV;
<ENG>environ	return ENVIRON;

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

<INITIAL,ENG>[/]  { BEGIN(REG); }

<INITIAL,ENG>\\   { BEGIN(ESC); }

<REG>[^\/]+	{ yylval.sval = &yytext[0]; return REGEX; }
<REG>[\/]	{ BEGIN(INITIAL); }

<ESC>.+	      	   return ESC_TEXT;
<ESC>[\n\r]{2}   { BEGIN(INITIAL); }

<PTH>[0-9a-zA-Z_/-]{1,255} { yylval.sval = gc_strdup(&yytext[0]); }
<PTH>::		       	   { BEGIN(INITIAL); return FILEPATH;     }	
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
