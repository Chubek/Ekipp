%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <sysexits.h>
#include <limits.h>
#include <ctype.h>

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

#define TOK_MAX	2

uint8_t engage_prefix_token[TOK_MAX + 1] = {0};
uint8_t define_prefix_token[TOK_MAX + 1] = {0};
uint8_t call_prefix_token[TOK_MAX + 1]   = {0};
uint8_t call_suffix_token[TOK_MAX + 1]   = {0};
uint8_t quote_left_token[TOK_MAX + 1]    = {0};
uint8_t quote_right_token[TOK_MAX + 1]   = {0};
uint8_t comment_left_token[TOK_MAX + 1]  = {0};
uint8_t comment_right_token[TOK_MAX + 1] = {0};
uint8_t delim_left_token[TOK_MAX + 1]    = {0};
uint8_t delim_right_token[TOK_MAX + 1]   = {0};
uint8_t template_delim_left_token[TOK_MAX + 1]  = {0};
uint8_t template_delim_right_token[TOK_MAX + 1] = {0};

#include "ekipp.h"
#include "yy.tab.h"
%}

Decimal		[0-9]+
Hexal		[0xX][a-fA-F0-9]+
Octal		[0oO][0-7]+
Binary		[0bB][0-1]+
Float		[0-9]*[eE\.][-+][0-9]+
Ident		[a-zA-Z\_][a-zA-Z\_0-9]*

%x ESC
%x ENG
%x REG
%x ARG
%x INB
%x EVALS
%x CALL
%x TMPL
%x PTH
%x DEFN
%x COMM
%x DEFNN
%x ENCLOSE
%x SQ_STR
%x DQ_STR
%x TBT_STR
%s DIV1
%s DIV2
%%
<*>[#!@%&<>{}:]{2} {
	if (!u8_strncmp(&engage_prefix_token[0], &yytext[0], 2)) {
		BEGIN(ENG); return ENGAGE_PREFIX;
	}
	else if (!u8_strncmp(&define_prefix_token[0], &yytext[0], 2)) {
		BEGIN(DEFN); return DEF_PREFIX;
	}
	else if (!u8_strncmp(&call_prefix_token[0], &yytext[0], 2)) {
		BEGIN(CALL); return CALL_PREFIX;
	}
        else if (!u8_strncmp(&call_suffix_token[0], &yytext[0], 2)) {
                BEGIN(INITIAL); return CALL_SUFFIX;
        }
        else if (!u8_strncmp(&quote_left_token[0], &yytext[0], 2)) {
                BEGIN(ENCLOSE); return QLEFT;
        }
        else if (!u8_strncmp(&quote_right_token[0], &yytext[0], 2)) {
                BEGIN(INITIAL); return QRIGHT;
        }
	else if (!u8_strncmp(&comment_left_token[0], &yytext[0], 2)) {
                BEGIN(COMM);
        }
        else if (!u8_strncmp(&comment_right_token[0], &yytext[0], 2)) {
                BEGIN(INITIAL);
        }
        else if (!u8_strncmp(&delim_left_token[0], &yytext[0], 2)) {
                BEGIN(ENCLOSE); return DLEFT;
        }
        else if (!u8_strncmp(&delim_right_token[0], &yytext[0], 2)) {
                BEGIN(INITIAL); return DRIGHT;
        } 
	else if (!u8_strncmp(&template_delim_left[0], &yytext[0], 2)) {
		BEGIN(TMPL); return TEMPLATE_DELIM_LEFT;
	} 
	else if (!u8_strncmp(&template_delim_right[0], &yytext[0], 2)) {
		BEGIN(INITIAL); return TEMPLATE_DELIM_RIGHT;
	}
	else
		ECHO;

}
<ENCLOSE>"\\"/[#!@%&<>{}:]{2} { 
	yylval.sval = GC_REALLOC(yylval.sval, yyleng + 1);
	yylval.sval[yyleng - 1] = yytext[1];
}
<ENCLOSE>[^#!@%&<>{}:]+ {
	yylval.sval = gc_strdup(&yytext[0]);
	return ENCLOSED;
}
<COMM>.		       REJECT;
<COMM>\n	       BEGIN(INITIAL);
<ENG>::	               BEGIN(PTH);
<DIV1>[$]	       return *yytext;
<DIV1>[\n]           { BEGIN(DIV2);    return *yytext; }
<ENG,EVALS,DEFN>[\n]+   { BEGIN(INITIAL); return *yytext;   }

<DEFN,CALL>[\r\n]	     REJECT;
<DEFN>define	     return DEFINE;
<DEFN>defeval	     return DEFEVAL;
<DEFN>exchange	     return EXCHANGE;
<DEFN,CALL,TMPL>{Ident}     { yylval.sval = gc_strdup(&yytext[0]);
				  return IDENT;		}
<DEFN>"=>"	     return CHEVRON;
<DEFN>"<>"	     return XCHN_MARK;
<DEFN>[$(]	     return *yytext;
<CALL>[(]	     { BEGIN(ARG);     return *yytext; 	 }
<CALL>[)]	     { BEGIN(INITIAL); return *yytext;   }

<ENG>[$?:]         return *yytext;
<ENG>[|]         { return *yytext; }

<*><<EOF>>	  { yyterminate();   }

<DIV2>.   { fputc(*yytext, yyout); }
<DIV2>\n  { fputc(*yytext, yyout); }

<EVALS,ENG>[$>&]      return *yytext;
<EVALS>[\*\+\-\%<>]   return *yytext;

<INITIAL>[ \t]	  ECHO;
<ESC,DIV1,ENG,REG,ARG,INB,EVALS,DEFN,CALL>[ \t] {};

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


<EVALS,TMPL>{Decimal}	 { yylval.ival = strtoll(yytext, NULL, 10); 
				return NUM;      }
<EVALS,TMPL>{Hexal}	 { yylval.ival = strtoll(&yytext[2], NULL, 16); 
				return NUM;      }
<EVALS,TMPL>{Octal}	 { yylval.ival = strtoll(&yytext[2], NULL, 8); 
				return NUM;      }
<EVALS,TMPL>{Binary}	 { yylval.ival = strtoll(&yytext[2], NULL, 2); 
				return NUM;      }
<TMPL>{Float}		 { yylval.fval = strtold(&yytext[0], NULL); 
				return FLOATNUM; }
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
<ENG>eval	{ BEGIN(EVALS); return EVAL;   }

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

<TMPL>[']      { BEGIN(SQ_STR);	return SQ;  }
<TMPL>["]      { BEGIN(DQ_STR); return DQ;  }
<TMPL>"```"    { BEGIN(TBT_STR); return TBT; }
<SQ_STR>[^']+  { yylval.sval = gc_strdup(&yytext[0]); return SQ_TXT;   }
<DQ_STR>[^"]+  { yylval.sval = gc_strdup(&yytext[0]); return DQ_TXT;   }
<TBT_STR>[^`]  { yylval.sval = gc_strdup(&yytext[0]); return TBT_TXT;  }
<SQ_STR>[^\\]/[']   { BEGIN(TMPL); return SQ;  }
<DQ_STR>[^\\]/["]   { BEGIN(TMPL); return DQ;  }
<SQ_STR>[^\\]/"```" { BEGIN(TMPL); return TBT; }

<TMPL>[;:,()=]  return *yytext;
<TMPL>:=	return INIT_ASSIGN;
<TMPL>for	return FOR;
<TMPL>while	return WHILE;
<TMPL>if	return IF;
<TMPL>then	return THEN;
<TMPL>do	return DO;
<TMPL>end	return END;
<TMPL>>>>	return OUTPUT;
<TMPL><<<	return INPUT;

<TMPL>openfile  return OPENFILE;
<TMPL>readfile  return READFILE;
<TMPL>writefile return WRITEFILE;
<TMPL>closefile return CLOSEFILE;

<TMPL>std::in	   return STD_IN;
<TMPL>std::out     return STD_OUT;
<TMPL>std::err     return STD_ERR;
<TMPL>file::this   return THIS_FILE;

<TMPL>"file::read::"/[0-9a-zA-Z_/\-\.]{1,255} {
			  yylval.handle.name = gc_strdup(&yytext[12]);
			  yylval.handle.mode = gc_strdup("r");
			  return FILE_HANDLE;
			}
<TMPL>"file::write::"/[0-9a-zA-Z_/\-\.]{1,255} {
			  yylval.handle.name = gc_strdup(&yytext[13]);
			  yylval.handle.mode = gc_strdup("w");
			  return FILE_HANDLE;
			}
<TMPL>"file::append::"/[0-9a-zA-Z_/\-\.]{1,255} {
			  yylval.handle.name = gc_strdup(&yytext[14]);
			  yylval.handle.mode = gc_strdup("a");
			  return FILE_HANDLE;
			}
<TMPL>"file::readwrite::"/[0-9a-zA-Z_/\-\.]{1,255} {
			  yylval.handle.name = gc_strdup(&yytext[17]);
			  yylval.handle.mode = gc_strdup("r+");
			  return FILE_HANDLE;
			}


<EVALS,TMPL>>=	 return GE;
<EVALS,TMPL>\<=	 return LE;
<EVALS,TMPL>==	 return EQ;
<EVALS,TMPL>!=	 return NE;
<EVALS,TMPL>>>	 return SHR;
<EVALS,TMPL>\<<	 return SHL;
<EVALS,TMPL>\*\* return POW;
<EVALS,TMPL>\+\+ return INCR;
<EVALS,TMPL>\-\- return DECR;

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
