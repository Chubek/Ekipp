#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <limits.h>
#include <string.h>
#include <wchar.h>
#include <regex.h>
#include <dirent.h>
#include <time.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>

#include "ekipp.h"
#include "errors.gen"

#define EEXIT(e, c) do { fputs(e, stderr); exit(c);  } while (0)

static struct LinkedList {
	struct LinkedList*		next;
	wchar_t*			name;
	wchar_t*			value;
} *Symtable;

void insert_symbol(wchar_t* name, wchar_t* value) {
	node_t* 	node	= calloc(1, sizeof(node_t));
	node->next	= Symtable;
	node->name	= wcsdup(name);
	node->value     = wcsdup(value);
	free(name);
	free(value);
	Symtable	= node;
}

wchar_t* get_symbol(wchar_t* name) {
	node_t* 	node;
	size_t 		len  = wcslen(name);

	for (node = Symtable; node != NULL; node = node->next) {
		if (!wcsncmp(node->name, name, len))
			return node->value;
	}
	return NULL;
}

void free_node(node_t* node) {
	free(node->name);
	free(node->value);
	free(node);
}

void remove_symbol(wchar_t* name) {
	node_t* 	node;
	size_t 		len  = wcslen(name);

	for (node = Symtable; node != NULL; node = node->next) {
		if (!wcsncmp(node->name, name, len)) {
			free(name);
			free_node(node);
		}
	}

}

void dump_symtable(void) {
	node_t*		node;

	for (node = Symtable; node != NULL; node = node->next)
		free_node(node);
}

#define MAX_STACK 	4096

static struct DefStack {
	wchar_t*	name;
	wchar_t*	value;
} Defstack[MAX_STACK];
size_t	stack_pointer = 0;

void push_stack(wchar_t* name, wchar_t* value) {
	Defstack[stack_pointer].name   = wcsdup(name);
	Defstack[stack_pointer].value  = wcsdup(value);
	free(name);
	free(value);
	stack_pointer++;
}

wchar_t* get_stack_value(wchar_t* name) {
	size_t len = wcslen(name);
	size_t ptr = stack_pointer;

	while (--ptr) {
		if (!wcsncmp(Defstack[ptr].value, name, len))
			return Defstack[ptr].value;
	}

	return NULL;
}

wchar_t* pop_stack(void) {
	return Defstack[--stack_pointer].value;
}

void dump_stack(void) {
	while (--stack_pointer) {
		free(Defstack[stack_pointer].name);
		free(Defstack[stack_pointer].value);
	}
}


#define NUM_DIVERT 	32

FILE*		divert_streams[NUM_DIVERT];
wchar_t*	divert_strings[NUM_DIVERT];
size_t		divert_lengths[NUM_DIVERT];
FILE*		current_divert;
DIR*		tmp_dir;
dev_t		null_dev;
int		null_fd;
FILE*		null_divert;
int		current_divert_idx;
FILE*		output;
FILE*		hold;

#define OUTPUT(ws) 		(fputws(ws, output))
#define OUTPUT_DIVERT(ws) 	(fputws(ws, current_divert))

#define MAJOR_NULL 1
#define MINOR_NULL 3

#define NULL_NAME "ekippnull"

void open_null_file(void) {
	tmp_dir = opendir(P_tmpdir);
	null_dev = makedev(MAJOR_NULL, MINOR_NULL);
	if ((null_fd = mknodat(dirfd(tmp_dir), 
					NULL_NAME, 
					S_IWUSR | S_IFCHR, 
					null_dev) < 0)) {
		EEXIT(ERR_OPEN_NULL, ECODE_OPEN_NULL);
	}
	null_divert = fdopen(null_fd, "w");
}

void destroy_null_divert(void) {
	if (null_divert) {
		fclose(null_divert);
		close(null_fd);
		closedir(tmp_dir);
	}
}

void set_divert(int n) {
	if (n > NUM_DIVERT) {
		EEXIT(ERR_NUM_DIVERT, ECODE_NUM_DIVERT);
	}
	else if (n < 0) {
		if (!null_divert) 
			open_null_file();
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


void unset_divert(int n) {
	if (n < 0) {
		EEXIT(ERR_UNSET_NULLDIV, ECODE_UNSET_NULLDIV);
	} else if (n >= NUM_DIVERT) {
		EEXIT(ERR_NUM_DIVERT, ECODE_NUM_DIVERT);
	} else {
		fwrite(divert_strings[n], divert_lengths[n], 1, output);
		free(divert_strings[n]);
		fclose(divert_streams[n]);
	}
}

void free_set_diverts(void) {
	int i = NUM_DIVERT;
	while (--i) {
		if (divert_streams[i]) {
			OUTPUT(divert_strings[i]);
			free(divert_strings[i]);
			fclose(divert_streams[i]);
		}
	}
	destroy_null_divert();
}

void switch_output(FILE* stream) {
	hold 	= output;
	output  = stream;
}

void unswitch_output(void) {
	output	= hold;
}

#define NMATCH		1
	regex_t		reg_cc;
regmatch_t	reg_pmatch[NMATCH];
char*		reg_input;
char*		reg_pattern;
wchar_t*	reg_matchmsg;
wchar_t*	reg_nomatchmsg;

void ifelse_regmatch(void) {
	if (regcomp(&reg_cc, reg_pattern, REG_NOSUB) < 0) {
		EEXIT(ERR_REG_COMP, ECODE_REG_COMP);
	}

	regexec(&reg_cc, reg_input, 0, NULL, 0)
		? OUTPUT(reg_nomatchmsg)
		: OUTPUT(reg_matchmsg);

	free(reg_input);
	free(reg_pattern);
	free(reg_matchmsg);
	free(reg_nomatchmsg);
	regfree(&reg_cc);
}

void search_file(FILE* stream) {
	wchar_t* line_str;
	wchar_t* word;
	size_t	 line_len;
	regoff_t start;
	regoff_t len;

	if (regcomp(&reg_cc, reg_pattern, 0) < 0) {
		EEXIT(ERR_REG_COMP, ECODE_REG_COMP);
	}

	for (int i = 0; i; i++) {
		if (!getline((char**)&line_str, &line_len, stream)) {
			if (!regexec(&reg_cc, 
					(char*)line_str, 
					NMATCH, 
					reg_pmatch, 
					0)) {
				start = reg_pmatch[0].rm_so;
				len   = reg_pmatch[0].rm_eo - start;
				wcsncpy(&word[0], &line_str[start], len);
				OUTPUT(word);
				free(word);
			}
		}
		free(line_str);
	}

	free(reg_pattern);
	regfree(&reg_cc);

}

void open_search_close(char* path) {
	FILE* stream = fopen(path, "r");
	search_file(stream);
	fclose(stream);
	free(path);
}

extern FILE* yyin;

void yyin_search(void) {
	FILE* yyin_cpy = yyin;
	search_file(yyin_cpy);
}

#define FLUSH_STDIO() (fflush(stdin), fflush(stdout), fflush(stderr))

char*		exec_cmd;
wchar_t*	exec_strcmp;
wchar_t*   	exec_strne;
wchar_t*	exec_streq;

void ifelse_execmatch(void) {
	FILE* pipe;
	FLUSH_STDIO();
	if (!(pipe = popen(exec_cmd, "r"))) {
		EEXIT(ERR_EXEC_SHELL, ECODE_EXEC_SHELL);
	}

	fseek(pipe, 0, SEEK_END);
	long len = ftell(pipe);
	if (len < 0) {
		OUTPUT(exec_strne);
		return;
	}

	rewind(pipe);

	wchar_t* readtxt = calloc(len, sizeof(wchar_t));
	fread(&readtxt[0], len, sizeof(wchar_t), pipe);
	(!wcsncmp(&readtxt[0], exec_strcmp, len))
		? OUTPUT(exec_streq)
		: OUTPUT(exec_strne);
	free(readtxt);
	pclose(pipe);
	free(exec_cmd);
	free(exec_strcmp);
	free(exec_strne);
	free(exec_streq);
}

void exec_command(void) {
	FILE* stream = popen(exec_cmd, "r");
	if (!stream) {
		EEXIT(ERR_EXEC_CMD, ECODE_EXEC_CMD);	
	}

	if (fseek(stream, 0, SEEK_END) < 0) {
		EEXIT(ERR_EXEC_READ, ECODE_EXEC_READ);
	}

	long len;
	if ((len = ftell(stream))) {
		EEXIT(ERR_EXEC_READ, ECODE_EXEC_READ);
	}

	rewind(stream);

	wchar_t* text = calloc(len, sizeof(wchar_t));
	if (fread(text, len, sizeof(wchar_t), stream) < 0) {
		EEXIT(ERR_EXEC_READ, ECODE_EXEC_READ);
	}

	OUTPUT(text);
	free(text);
	pclose(stream);
	free(exec_cmd);
}

FILE*		delim_stream;
char		delim_fpath[FILENAME_MAX];
char*		delim_command;	

#define OUTPUT_DELIM(ws) (fputws(ws, delim_stream))

void init_delim_stream(wchar_t* text, size_t len) {
	memset(&delim_fpath[0], 0, FILENAME_MAX);
	delim_fpath[0] = 'X'; delim_fpath[1] = 'X'; delim_fpath[2] = 'X';
	delim_fpath[3] = 'X'; delim_fpath[4] = 'X'; delim_fpath[5] = 'E';
	if (mkstemp(&delim_fpath[0]) < 0) {
		EEXIT(ERR_DELIM_FPATH, ECODE_DELIM_FPATH);
	}

	if (!(delim_stream = fopen(&delim_fpath[0], "w"))) {
		EEXIT(ERR_DELIM_OPEN, ECODE_DELIM_OPEN);
	}

	if (fwrite(text, len, sizeof(wchar_t), delim_stream) < 0) {
		EEXIT(ERR_DELIM_WRITE, ECODE_DELIM_WRITE);
	}
}

void exec_delim_command(void) {
	FLUSH_STDIO();
	fclose(delim_stream);
	if (!(delim_stream = freopen(&delim_fpath[0], "r", stdin))) {
		EEXIT(ERR_DELIM_REOPEN, ECODE_DELIM_REOPEN);
	}

	FILE* pipe = popen(delim_command, "r");

	fseek(pipe, 0, SEEK_END);
	long len = ftell(pipe);

	if (len < 0) {
		return;	
	}

	rewind(pipe);

	wchar_t* readtxt = calloc(len, sizeof(wchar_t));
	fread(&readtxt[0], len, sizeof(wchar_t), pipe);
	OUTPUT(readtxt);
	free(readtxt);
	pclose(pipe);
	fclose(delim_stream);
	free(delim_command);
}
#define MAX_TOKEN	8
#define REGISTRY_SIZE	65536

char	quote_left[MAX_TOKEN];
char	quote_right[MAX_TOKEN];
char	comment_left[MAX_TOKEN];
char	comment_right[MAX_TOKEN];
	char	delim_left[MAX_TOKEN];
char	delim_right[MAX_TOKEN];
char	argnum_sigil[MAX_TOKEN];
char	engage_sigil[MAX_TOKEN];
char	cond_sigil[MAX_TOKEN];
char	search_sigil[MAX_TOKEN];
char	aux_sigil[MAX_TOKEN];

#define MAX_FMT		MAX_TOKEN * 8

   char fmt_delim[MAX_FMT]; 
   char fmt_comment[MAX_FMT];
   char fmt_quote[MAX_FMT];

bool	tokens_registry[REGISTRY_SIZE];

void zero_registry(void) {
	memset(&tokens_registry[0], false, sizeof(bool) * REGISTRY_SIZE);
}

void register_token(char* token) {
	uint16_t hash = 0;
	char	 c;
	
	while ((c = *token++))
		hash = (hash * 33) + c;

	if (tokens_registry[hash] == true) {
		EEXIT(ERR_TOKEN_REREGISTER, ECODE_TOKEN_REREGISTER);
	}

	tokens_registry[hash] = true;
}

void set_token(char* token, char* value) {
	register_token(value);
	memset(&token[0], 0, MAX_TOKEN);
	memmove(&token[0], &value[0], MAX_TOKEN);
	reformat_fmts();
	free(token);
	free(value);
}

void reformat_fmts(void) {
	sprintf(&fmt_delim[0], 
			"%s%%s%s", &delim_left[0], &delim_right[0]);
	
	sprintf(&fmt_comment[0], 
			"%s%%*s%s", &comment_left[0], &comment_right[0]);

	sprintf(&fmt_quote[0], 
			"%s%%s%s", &quote_left[0], &quote_right[0]);
}

bool token_is(char* token, char* cmp, size_t len) {
	return !strncmp(token, cmp, len);
}


extern void 		yyinvoke(wchar_t* code);
char			keyletter;

#ifndef ARG_MAX
#define ARG_MAX		1024
#endif

wchar_t* invoke_argv[ARG_MAX];
wchar_t* joined_argv;
size_t	 invoke_argc = 0;
size_t	 invoke_argn = 0;

void invoke_addarg(wchar_t* arg) {
	invoke_argv[invoke_argc++] = wcsdup(arg);
	free(arg);
}

wchar_t* invoke_getarg(size_t n) {
	return invoke_argv[n];
}

void invoke_printnext(void) {
	OUTPUT(invoke_argv[invoke_argn++]);
}

void invoke_printarg(size_t n) {
	if (n < invoke_argc) {
		OUTPUT(invoke_argv[n]);
	}
}

void invoke_joinargs(wchar_t* delim) {
	size_t n = 0;
	size_t l = 0;
	size_t i = 0;
	while (n < invoke_argc - 1) {
		l = wcslen(invoke_argv[n]);
		wcsncat(&joined_argv[i], &invoke_argv[n++][0], l);
		i += l;
	}
	l = wcslen(invoke_argv[++n]);
	wcsncat(&joined_argv[i], &invoke_argv[n][0], l);
	free(delim);
}

void invoke_printargs(wchar_t* delim) {
	size_t n = 0;
	while (n < invoke_argc - 1) {
		OUTPUT(invoke_argv[n++]);
		OUTPUT(delim);
	}

	OUTPUT(invoke_argv[n]);
	free(delim);
}

void invoke_dumpargs(void) {
	while (--invoke_argc)
		free(invoke_argv[invoke_argc]);
	memset(&invoke_argv[0], 0, ARG_MAX * sizeof(wchar_t*));
	invoke_argn = 0;
	if (joined_argv)
		free(joined_argv);
}

void invoke_macro(wchar_t *id) {
	wchar_t* macro = get_symbol(id);
	if (!macro)
		macro = get_stack_value(id);
	if (!macro) {
		EEXIT(ERR_UNKNOWN_MACRO, ECODE_UNKNOWN_MACRO);
	}
	yyinvoke(macro);
	free(id);
}

wchar_t*	fmt;

void print_formatted(void) {
	wchar_t wc;
	wchar_t f[3] = {0};
	int i = 0;

	while ((wc = *fmt++) && i < invoke_argc) {
		if (wc == L'%' && *fmt != L'%') {
			f[0] = L'%';
			f[1] = *fmt++;
			fwprintf(output, &f[0], invoke_argv[i++]);
		}
	}

}


void print_env(char* key) {
	char* var;
	if ((var = getenv(key)) != NULL)
		fputs(var, output);
	free(key);
}

extern char** sys_argv;
extern int    sys_argc;

void print_argv(int n) {
	if (sys_argc < n) {
		fputs(sys_argv[n], output);
	}
}

wchar_t*	aux_prim;
wchar_t*	aux_sec;
wchar_t*	aux_tert;

void set_aux(wchar_t** aux, wchar_t* value) {
	*aux = wcsdup(value);
}

void free_aux(wchar_t* aux) {
	free(aux);
}

void translit(int action) {
	#define INPUT 		aux_prim
	#define SRCMAP		aux_sec
	#define DSTMAP		aux_tert

	wchar_t 	wc   = 0;
	wchar_t* 	wcp  = 0;
	size_t		offs = 0;
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

	free_aux(INPUT); free_aux(SRCMAP); free_aux(DSTMAP);

	#undef INPUT
	#undef SRCMAP
	#undef DSTMAP
}

void offset(void) {
	#define INPUT		aux_prim
	#define SUB		aux_sec

	fwprintf(output, L"%lp", wcsstr(INPUT, SUB) - INPUT);

	#undef INPUT
	#undef SUB
}

void list_dir(void) {
	#define DIR_PATH 	aux_prim

	DIR* stream = opendir((char*)DIR_PATH);
	if (!stream) {
		EEXIT(ERR_NO_DIR, ECODE_NO_DIR);
	}

	struct dirent* entry;
	int i = 0;

	while ((entry = readdir(stream)) != NULL) {
		fprintf(output, 
				"%d -- %s\n", 
				++i,
				&entry->d_name[0]
			);
		free(entry);
	}

	closedir(stream);
	free_aux(DIR_PATH);

	#undef DIR_PATH
}

void cat_file(void) {
	#define FILE_PATH	aux_prim

	FILE*	stream	= fopen((char*)FILE_PATH, "r");
	if (fseek(stream, 0, SEEK_END) < 0) {
		EEXIT(ERR_CAT_FAIL, ECODE_CAT_FAIL);
	}

	long len = ftell(stream);
	if (len < 0) {
		fclose(stream);
		return;
	}

	rewind(stream);

	wchar_t* text = calloc(len, sizeof(wchar_t));
	if (fread(&text[0], len, sizeof(wchar_t), stream) < 0) {
		EEXIT(ERR_CAT_FAIL, ECODE_CAT_FAIL);
	}

	OUTPUT(text);

	fclose(stream);
	free(text);

	free_aux(FILE_PATH);

	#undef FILE_PATH
}

void include_file(void) { cat_file(); }

#define OUT_TIME_MAX 1024

void format_time(void) {
	#define FMT	aux_prim

	char out_time[OUT_TIME_MAX];
	time_t t;
	struct tm* tmp;

	t 	= time(NULL);
	tmp 	= localtime(&t);
	if (tmp == NULL) {
		EEXIT(ERR_FORMAT_TIME, ECODE_FORMAT_TIME);
	}

	if (strftime(&out_time[0], OUT_TIME_MAX, (char*)fmt, tmp) == 0) {
		EEXIT(ERR_FORMAT_TIME, ECODE_FORMAT_TIME);
	}

	fputs(&out_time[0], output);

	free_aux(FMT);

	#undef FMT
}

void dnl(void) {
	fscanf(yyin, "%*s\n");
}

void do_on_exit(void) {
	dump_symtable();
	dump_stack();
	free_set_diverts();
	invoke_dumpargs();
}
















