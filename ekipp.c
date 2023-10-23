#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <limits.h>
#include <string.h>
#include <wchar.h>

#define Local 			static
#define Inline			static inline
#define SYMTABLE_LEN_STEP	64

#define ERR_OUT(e, c) do { fputs(e, stderr); exit(c);  } while (0)

Local struct LinkedList {
	struct LinkedList*		next;
	wchar_t*			name;
	wchar_t*			value;
} *Symtable;
typedef struct LinkedList node_t;

Inline void insert_symbol(wchar_t* name, wchar_t* value) {
	node_t* 	node	= calloc(sizeof(node_t));
	node->next	= Symtable;
	node->name	= name;
	node->value     = value;
	Symtable	= node;
	Symtable_Cnt++;
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

Inline void dump_symtable(void) {
	node_t*		node;

	for (node = Symtable; node != NULL; node = node->next)
		free(node);
}


#define NUM_DIVERT 	9
#define NULL_DEVICE 	"/dev/null"

Local   FILE*		divert_streams[NUM_DIVERT];
Local 	wchar_t*	divert_strings[NUM_DIVERT];
Local 	size_t		divert_lengths[NUM_DIVERT];
Local	FILE*		current_divert;
Local	FILE*		null_divert;

#define OUTPUT_DIVERT(ws) (fputws(ws, current_divert))

Inline void set_divert(int n) {
	if (n > NUM_DIVERT) {
		ERR_OUT(ERR_NUM_DIVERT, CODE_NUM_DIVERT);
	}
	else if (n < 0) {
		if (!null_divert) 
			null_divert = fopen(NULL_DEVICE, "w");
		current_divert = null_divert;
	} else if (n >= 0) {
		if (!divert_streams[n])
			divert_streams[n] = 
				open_wmemstream(&divert_strings[n],
						&divert_lengths[n]);
		current_divert = divert_streams[n];
	} else {
		return;
	}
}

Local	FILE*		input;
Local	FILE*		output;

#define OUTPUT(ws) 	(fputws(ws, output));


Local 	regex_t		reg_cc;
Local	uint8_t*	reg_input;
Local	uint8_t*	reg_pattern;
Local	uint8_t*	reg_matchmsg;
Local	uint8_t*	reg_nomatchmsg;

Inline void ifelse_regmatch(void) {
	if (regcomp(&reg_cc, reg_pattern, REG_NOSUB) < 0) {
		ERR_OUT(ERR_REG_COMP, CODE_REG_COMP);
	}

	regexec(&reg_cc, reg_input, 0, NULL, 0)
		? OUTPUT(reg_nomatchmsg)
		: OUTPUT(reg_matchmsg);

	regfree(&reg_cc);
}

typedef long double fltmax_t;

Local uint8_t*		eval_expr;
Local union EvalRes {
	fltmax_t 	fltnum;
	intmax_t	intnum;
} Evalres;
typedef union EvalRes evres_t;

#define FLOAT_RES(f)	(Evalres.fltnum = f)
#define INT_RES(i)	(Evalres.intnum = i)


Local evres_t		eval_cmp;
Local uint8_t*		eval_ifeq;
Local uint8_t* 		eval_ifne;

Inline void ifelse_evalmatch(void) {
	if (yyevalexpr()) {
		ERR_OUT(ERR_EVAL_MATCH, CODE_EVAL_MATCH);
	}
	
	(eval_cmp == Evalres)
		? OUTPUT(eval_ifeq)
		: OUTPUT(eval_ifne);
}

Local uint8_t*		exec_shell;
Local uint8_t*		exec_strcmp;
Local uint8_t*		exec_streq;
Local uint8_t*		exec_strne;

#define FLUSH_STDIO() (fflush(stdin), fflush(stdout), fflush(stderr))

Inline void ifelse_execmatch(void) {
	FILE* pipe;
	FLUSH_STDIO();
	if (!(pipe = popen(exec_shell, "r"))) {
		ERR_OUT(ERR_EXEC_SHELL, CODE_EXEC_SHELL);
	}

	fseek(pipe, 0, SEEK_END);
	long len = ftell(pipe);
	if (len < 0) {
		OUTPUT(exec_strne);
		return;
	}

	uint8_t* readtxt = calloc(len, sizeof(uint8_t));

	fread(&readtxt[0], len, sizeof(uint8_t), pipe);

	(!wcsncmp(&readtxt[0], exec_strcmp, len))
		? OUTPUT(exec_streq)
		: OUTPUT(exec_strne);

	free(readtxt);
}

Local FILE*		delim_stream;
Local char		delim_fpath[MAX_PATH];
Local uint8_t*		delim_command;	

#define OUTPUT_DELIM(ws) (fputws(ws, delim_stream))

Inline void init_delim_stream(void) {
	memset(&delim_fpath[0], 0, MAX_PATH);
	delim_fpath[0] = 'X'; delim_fpath[1] = 'X'; delim_fpath[2] = 'X';
	delim_fpath[3] = 'X'; delim_fpath[4] = 'X'; delim_fpath[5] = 'E';
	if (mkstemp(&delim_fpath) < 0) {
		ERR_OUT(ERR_DELIM_FPATH, CODE_DELIM_FPATH);
	}

	if (!(delim_stream = fopen(&delim_fpath[0], "w"))) {
		ERR_OUT(ERR_DELIM_OPEN, CODE_DELIM_OPEN);
	}
}

Inline void exec_delim_command(void) {
	FLUSH_STDIO();
	fclose(delim_stream);
	if (!(delim_stream = freopen(&delim_fpath[0], "r", stdin))) {
		ERR_OUT(ERR_DELIM_REOPEN, CODE_DELIM_REOPEN);
	}

	FILE* pipe = popen(delim_command, "r");

	fseek(pipe, 0, SEEK_END);
	long len = ftell(pipe);

	if (len < 0) {
		return;	
	}

	uint8_t* readtxt = calloc(len, sizeof(uint8_t));
	fread(&readtxt[0], len, sizeof(uint8_t), pipe);
	OUTPUT(readtxt);
	free(readtxt);

}








