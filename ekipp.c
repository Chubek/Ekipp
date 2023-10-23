#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <limits.h>
#include <string.h>
#include <wchar.h>
#include <regex.h>

#define Local 			static
#define Inline			static inline
#define External		extern

#define ERR_OUT(e, c) do { fputs(e, stderr); exit(c);  } while (0)

Local struct LinkedList {
	struct LinkedList*		next;
	wchar_t*			name;
	wchar_t*			value;
} *Symtable;
typedef struct LinkedList node_t;

Inline void insert_symbol(wchar_t* name, wchar_t* value) {
	node_t* 	node	= calloc(1, sizeof(node_t));
	node->next	= Symtable;
	node->name	= wcsdup(name);
	node->value     = wcsdup(value);
	Symtable	= node;
}

Inline wchar_t* get_symbol(wchar_t* name) {
	node_t* 	node;
	size_t 		len  = wcslen(name);

	for (node = Symtable; node != NULL; node = node->next) {
		if (!wcsncmp(node->name, name, len))
			return node->value;
	}
	return NULL;
}

Inline void free_node(node_t* node) {
	free(node->name);
	free(node->value);
}

Inline void dump_symtable(void) {
	node_t*		node;

	for (node = Symtable; node != NULL; node = node->next)
		free_node(node);
}


#define NUM_DIVERT 	9
#define NULL_DEVICE 	"/dev/null"

Local   FILE*		divert_streams[NUM_DIVERT];
Local 	wchar_t*	divert_strings[NUM_DIVERT];
Local 	size_t		divert_lengths[NUM_DIVERT];
Local	FILE*		current_divert;
Local	FILE*		null_divert;
Local	int		current_divert_idx;
Local	FILE*		output;

#define OUTPUT(ws) 	(fputws(ws, output))
#define OUTPUT_DIVERT(ws) (fputws(ws, current_divert))

Inline void set_divert(int n) {
	if (n > NUM_DIVERT) {
		ERR_OUT(ERR_NUM_DIVERT, ECODE_NUM_DIVERT);
	}
	else if (n < 0) {
		if (!null_divert) 
			null_divert = fopen(NULL_DEVICE, "w");
		current_divert 	   = null_divert;
		current_divert_idx = -1;
	} else {
		if (!divert_streams[n])
			divert_streams[n] = 
				open_wmemstream(&divert_strings[n],
						&divert_lengths[n]);
		current_divert 	   = divert_streams[n];
		current_divert_idx = n;
	}
}

Inline void unset_divert(int n) {
	if (n < 0) {
		ERR_OUT(ERR_UNSET_NULLDIV, ECODE_UNSET_NULLDIV);
	} else if (n >= NUM_DIVERT) {
		ERR_OUT(ERR_NUM_DIVERT, ECODE_NUM_DIVERT);
	} else {
		fwrite(divert_strings[n], divert_lengths[n], 1, output);
		free(divert_strings[n]);
		fclose(divert_streams[n]);
	}
}

Inline void free_set_diverts(void) {
	int i = NUM_DIVERT;
	while (--i) {
		if (divert_streams[i]) {
			OUTPUT(divert_strings[i]);
			free(divert_strings[i]);
			fclose(divert_streams[i]);
		}
	}
}

Local 	regex_t		reg_cc;
Local	char*		reg_input;
Local	char*		reg_pattern;
Local	wchar_t*	reg_matchmsg;
Local	wchar_t*	reg_nomatchmsg;

Inline void ifelse_regmatch(void) {
	if (regcomp(&reg_cc, reg_pattern, REG_NOSUB) < 0) {
		ERR_OUT(ERR_REG_COMP, ECODE_REG_COMP);
	}

	regexec(&reg_cc, reg_input, 0, NULL, 0)
		? OUTPUT(reg_nomatchmsg)
		: OUTPUT(reg_matchmsg);

	regfree(&reg_cc);
}

#define FLUSH_STDIO() (fflush(stdin), fflush(stdout), fflush(stderr))

Inline void ifelse_execmatch(void) {
	FILE* pipe;
	FLUSH_STDIO();
	if (!(pipe = popen(exec_shell, "r"))) {
		ERR_OUT(ERR_EXEC_SHELL, ECODE_EXEC_SHELL);
	}

	fseek(pipe, 0, SEEK_END);
	long len = ftell(pipe);
	if (len < 0) {
		OUTPUT(exec_strne);
		return;
	}

	wchar_t* readtxt = calloc(len, sizeof(wchar_t));
	fread(&readtxt[0], len, sizeof(wchar_t), pipe);
	(!wcsncmp(&readtxt[0], exec_strcmp, len))
		? OUTPUT(exec_streq)
		: OUTPUT(exec_strne);
	free(readtxt);
}

Local FILE*		delim_stream;
Local char		delim_fpath[MAX_PATH];
Local char*		delim_command;	

#define OUTPUT_DELIM(ws) (fputws(ws, delim_stream))

Inline void init_delim_stream(void) {
	memset(&delim_fpath[0], 0, MAX_PATH);
	delim_fpath[0] = 'X'; delim_fpath[1] = 'X'; delim_fpath[2] = 'X';
	delim_fpath[3] = 'X'; delim_fpath[4] = 'X'; delim_fpath[5] = 'E';
	if (mkstemp(&delim_fpath) < 0) {
		ERR_OUT(ERR_DELIM_FPATH, ECODE_DELIM_FPATH);
	}

	if (!(delim_stream = fopen(&delim_fpath[0], "w"))) {
		ERR_OUT(ERR_DELIM_OPEN, ECODE_DELIM_OPEN);
	}
}

Inline void exec_delim_command(void) {
	FLUSH_STDIO();
	fclose(delim_stream);
	if (!(delim_stream = freopen(&delim_fpath[0], "r", stdin))) {
		ERR_OUT(ERR_DELIM_REOPEN, ECODE_DELIM_REOPEN);
	}

	FILE* pipe = popen(delim_command, "r");

	fseek(pipe, 0, SEEK_END);
	long len = ftell(pipe);

	if (len < 0) {
		return;	
	}

	wchar_t* readtxt = calloc(len, sizeof(wchar_t));
	fread(&readtxt[0], len, sizeof(wchar_t), pipe);
	OUTPUT(readtxt);
	free(readtxt);
}
#define MAX_TOKEN	8
#define LUT_SIZE	65536

Local	char	quote_left[MAX_TOKEN];
Local	char	quote_right[MAX_TOKEN];
Local	char	comment_left[MAX_TOKEN];
Local	char	comment_right[MAX_TOKEN];
Local	char	divert_mark[MAX_TOKEN];
Local	char	wrap_mark[MAX_TOKEN];
Local 	char	delim_left[MAX_TOKEN];
Local	char	delim_right[MAX_TOKEN];
Local	char	argnum_sigil[MAX_TOKEN];
Local	char	engage_sigil[MAX_TOKEN];

Inline void set_token(char* token, char* value) {
	memset(&token[0], 0, MAX_TOKEN);
	memmove(&token[0], &value[0], MAX_TOKEN);
}

Inline bool token_is(char* token, char* inquiry) {
	return !strcmp(&inquiry[0], token);
}

External  void 		yyinvoke(wchar_t* code);
Local	  wchar_t* 	invoke_argv[MAX_ARG];
Local	  size_t	invoke_argc = 0;

Inline void invoke_addarg(wchar_t* arg) {
	invoke_argv[invoke_argc++] = wcsdup(arg);
}

Inline void invoke_dumpargs(void) {
	while (--invoke_argc)
		free(invoke_argv[invoke_argc]);
	memset(&invoke_argv[0], 0, MAX_ARG * sizeof(wchar_t*));
}

Inline void invoke_macro(wchar_t *id) {
	wchar_t* macro = get_symbol(id);
	yyinvoke(macro);
}

Local wchar_t*	aux_prim;
Local wchar_t*	aux_sec;
Local wchar_t*	aux_tert;
Local wchar_t*	aux_quat;
Local wchar_t*	aux_result;


Inline void translit(int action) {
	#define INPUT 		aux_prim
	#define SRCMAP		aux_sec
	#define DSTMAP		aux_tert
	wchar_t 	wc;
	wchar_t* 	wcp;
	size_t		offs;
	size_t		lendst = wcslen(DSTMAP);

	while ((wc = *INPUT++)) {
		if ((wcp = wcschr(SRCMAP, wc), offs = wcp - SRCMAP)) {
			if (offs < lendst)
				fputwc(DSTMAP[offs], output);
			else
				break;
		} else
			fputwc(wc, output);
	}
	OUTPUT(&INPUT[++offs]);

	#undef INPUT
	#undef SRCMAP
	#undef DSTMAP
}

Inline void offset(void) {
	#define INPUT		aux_prim
	#define SUB		aux_sec

	fwprintf(output, "%lp", wcsstr(INPUT, SUB) - INPUT);

	#undef INPUT
	#undef SUB
}


Local void do_at_exit(void) {
	dump_symtable();
	free_set_diverts();
	invoke_dumpargs();
}
















