%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <sysexits.h>
#include <limits.h>

#include <unistr.h>
#include <unistdio.h>
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
%x CAL
%x PTH
%x DEF
%s DIV1
%s DIV2
%%
	fflush(yyout);
<*>"/*"	               BEGIN(COM);
<ENG>::	               BEGIN(PTH);
<DIV1>[$]	       return *yytext;
<DIV1>[\n]           { BEGIN(DIV2);    return *yytext; }
<INITIAL,DIV2>^"#!"  { BEGIN(ENG);     return ENGAGE_PREFIX; }
<ENG,EVL,DEF>[\n]+   { BEGIN(INITIAL); return *yytext;   }

<DEF,CAL>[\r\n]	     REJECT;
<CAL>"!$"	     { BEGIN(INITIAL); return CALL_SUFFIX; }
<DEF>define	     return DEFINE;
<DEF>defeval	     return DEFEVAL;
<DEF>exchange	     return EXCHANGE;
<INITIAL>"@!"	     { BEGIN(DEF); return DEF_PREFIX;  }
<INITIAL>"$!"	     { BEGIN(CAL); return CALL_PREFIX; }
<DEF,CAL>{Ident}     { yylval.sval = gc_strdup(&yytext[0]);
				  return IDENT;		}
<DEF>"=>"	     return CHEVRON;
<DEF>"<>"	     return XCHN_MARK;
<DEF>[$(]	     return *yytext;
<CAL>[(]	     { BEGIN(ARG);     return *yytext; 	 }
<CAL>[)]	     { BEGIN(INITIAL); return *yytext;   }

<DEF,ENG>"''"	   BEGIN(QUO);
<ENG>[$?:]         return *yytext;
<ENG>[|]         { BEGIN(DLM1); return *yytext; }
<DLM1>{LimOpen}    BEGIN(DLM2);

<*><<EOF>>	  { yyterminate();   }

<COM>[^\*\/]       REJECT;
<COM>"*/"          BEGIN(INITIAL);

<DLM2>[^=>]+      { yylval.sval = gc_strdup(&yytext[0]);
			return DELIMITED;   }
<DLM2>{LimClose}   BEGIN(INITIAL);

<QUO>\\'	  { yylval.sval[yyleng - 1] = '\'';    }
<QUO>[^']+        { yylval.sval = gc_strdup(&yytext[0]);
			return QUOTED;	    }
<QUO>"''"            BEGIN(ENG);

<DIV2>.   { fputc(*yytext, yyout); }
<DIV2>\n  { fputc(*yytext, yyout); }

<EVL,ENG>[$>&]      return *yytext;
<EVL>[\*\+\-\%<>]   return *yytext;

<INITIAL>[ \t]	  ECHO;
<ESC,DIV1,ENG,REG,ARG,INB,EVL,DEF,CAL>[ \t] {};

<ENG>[(]	 { BEGIN(ARG); return *yytext; }
<ARG>[,$]	   return *yytext;
<ARG>[)]         { BEGIN(ENG); return *yytext; }
<ARG>{Decimal}  |
   {Hexal}	|
   {Octal}      |
   {Binary}	 { yylval.sval = gc_strdup(&yytext[0]);
   				return ARG_NUM;         }
<ARG>"$"{Ident}	 { yylval.sval = gc_strdup(&yytext[1]); 
				return ARG_IDENT;       }
<ARG>[^$^(^)^,^ ]+ { yylval.sval = gc_strdup(&yytext[0]);
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

<ENG>eq		{ yylval.cmpval = IFEXEC_EQ; return IFEX; }
<ENG>ne		{ yylval.cmpval = IFEXEC_NE; return IFEX; }
<ENG>gt		{ yylval.cmpval = IFEXEC_GT; return IFEX; }
<ENG>ge		{ yylval.cmpval = IFEXEC_GE; return IFEX; }
<ENG>lt		{ yylval.cmpval = IFEXEC_LT; return IFEX; }
<ENG>le		{ yylval.cmpval = IFEXEC_LE; return IFEX; }

<ENG>lsdir	return LSDIR;
<ENG>translit	return TRANSLIT;
<ENG>catfile	return CATFILE;
<ENG>offset	return OFFSET;
<ENG>datetime	return DATETIME;
<ENG>patsub 	return PATSUB;
<ENG>substitute return SUBSTITUTE;

<ENG>divert     { BEGIN(DIV1); return DIVERT;   }
<ENG>undivert	{ BEGIN(DIV1); return UNDIVERT; }

<ENG>exec	return EXEC;
<ENG>delimexec  return EXEC_DELIM;
<ENG>eval	{ BEGIN(EVL); return EVAL;   }

<ENG>reflect	return REFLECT;
<ENG>current	return CURRENT;
<ENG>search	return SEARCH;

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

<REG>[^\/]+	{ yylval.sval = gc_strdup(&yytext[0]); return REGEX; }
<REG>[\/]	{ BEGIN(INITIAL); }

<ESC>.+	      	   return ESC_TEXT;
<ESC>[\n\r]{2}   { BEGIN(INITIAL); }

<PTH>[0-9a-zA-Z_/\-\.]{1,255} { yylval.sval = gc_strdup(&yytext[0]); }
<PTH>::		       	   { BEGIN(INITIAL); return FILEPATH;     }	
%%

void yyerror(const char* err) {
	fputs(err,  stderr);
	fputc('\n', stderr);
}

int yywrap(void) {
	input_idx++;
	if (input_idx == MAX_INPUT - 1 
		|| !input_files[input_idx][0])
		return 1;
	else {
		putchar('\n');
		if (yyin) 
			fclose(yyin);
		yyin = fopen(&input_files[input_idx++][0], "r");
		if (!yyin) {
			fprintf(stderr, "Error: file \"%s\" not found\n",
				&input_files[input_idx - 1][0]);
			exit(EX_IOERR);
		}
		return 0;
	}
}
