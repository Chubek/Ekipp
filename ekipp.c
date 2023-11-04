#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <limits.h>
#include <string.h>
#include <wchar.h>
#include <regex.h>
#include <dirent.h>
#include <stddef.h>
#include <inttypes.h>
#include <time.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>

#include <gc.h>

#include "ekipp.h"
#include "errors.gen"

#define EEXIT(e, c) do { fputs(e, stderr); exit(c);  } while (0)

static struct LinkedList {
	struct LinkedList*		next;
	wchar_t*			name;
	wchar_t*			value;
} *Symtable;

void insert_symbol(wchar_t* name, wchar_t* value) {
	node_t* 	node	= GC_MALLOC(sizeof(node_t));
	node->next	= Symtable;
	node->name	= gc_wcsdup(name);
	node->value     = gc_wcsdup(value);
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


void remove_symbol(wchar_t* name) {
	node_t* 	node;
	size_t 		len  = wcslen(name);

	for (node = Symtable; node != NULL; node = node->next) {
		if (!wcsncmp(node->name, name, len)) {
			GC_FREE(node);
		}
	}

}


#define MAX_STACK 	4096

static struct DefStack {
	wchar_t*	name;
	wchar_t*	value;
} Defstack[MAX_STACK];
size_t	stack_pointer = 0;

void push_stack(wchar_t* name, wchar_t* value) {
	Defstack[stack_pointer].name   = gc_wcsdup(name);
	Defstack[stack_pointer].value  = gc_wcsdup(value);
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


#define NUM_DIVERT 	10

extern FILE*	yyout;

FILE*		divert_streams[NUM_DIVERT];
wchar_t*	divert_strings[NUM_DIVERT];
size_t		divert_lengths[NUM_DIVERT];
FILE*		current_divert;
DIR*		tmp_dir;
dev_t		null_dev;
int		null_fd;
FILE*		null_divert;
int		current_divert_idx;
FILE*		hold;

#define OUTPUT(ws) 		(fputws(ws, yyout))
#define OUTPUT_DIVERT(ws) 	(fputws(ws, current_divert))

#define MAJOR_NULL 1
#define MINOR_NULL 5

#define NULL_NAME "ekippnull"
#define NULL_LEN  16

void open_null_file(void) {
	char nullname[NULL_LEN] = {0};
	strncpy(&nullname[0], NULL_NAME, NULL_LEN);
	strfry(&nullname[0]);
	tmp_dir = opendir(P_tmpdir);
	null_dev = makedev(MAJOR_NULL, MINOR_NULL);
	if ((null_fd = mknodat(dirfd(tmp_dir), 
					&nullname[0], 
					S_IWUSR | S_IFREG,
					null_dev)) < 0) {
		EEXIT(ERR_OPEN_NULL, ECODE_OPEN_NULL);
	}
	null_divert = fdopen(null_fd, "w");
}

void destroy_null_divert(void) {
	if (null_divert != NULL) {
		fclose(null_divert);
		close(null_fd);
		closedir(tmp_dir);
		null_divert = NULL;
	}
}

void set_divert(int n) {
	if (n >= NUM_DIVERT) {
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
		destroy_null_divert();
	} else if (n >= NUM_DIVERT) {
		EEXIT(ERR_NUM_DIVERT, ECODE_NUM_DIVERT);	
	} else if (divert_strings[n] != NULL) {
		fwrite(divert_strings[n], divert_lengths[n], 
				sizeof(wchar_t), yyout);
		free(divert_strings[n]);
		divert_strings[n] = NULL;
	}
}

void free_set_diverts(void) {
	int i = NUM_DIVERT;
	while (--i) {
		if (divert_streams[i] != NULL) {
			if (divert_strings[i] != NULL) {
				OUTPUT(divert_strings[i]);
				free(divert_strings[i]);
			}
		}
	}
	destroy_null_divert();
}

void init_hold(void) {
	hold = yyout;
}

void switch_output(FILE* stream) {
	yyout   = stream;
}

void unswitch_output(void) {
	fflush(yyout);
	yyout	= hold;
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

	regfree(&reg_cc);

}

void open_search_close(char* path) {
	FILE* stream = fopen(path, "r");
	search_file(stream);
	fclose(stream);
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

#define BUFLEN 1024

void ifelse_execmatch(void) {
	FILE* stream;
	FLUSH_STDIO();
	if (!(stream = popen(exec_cmd, "r"))) {
		EEXIT(ERR_EXEC_CMD, ECODE_EXEC_CMD);
	}
	FLUSH_STDIO();
	fflush(stream);

	char*   line = GC_MALLOC(LINE_MAX);
	ssize_t reads;
	size_t  readn;
	while ((reads = getline(&line, &readn, stream)) > 0)
		fputs(line, yyout);

	pclose(stream);
}


void exec_command(void) {
	FILE* stream = popen(exec_cmd, "r");
	FLUSH_STDIO();
	if (!stream) {
		EEXIT(ERR_EXEC_CMD, ECODE_EXEC_CMD);	
	}

	FLUSH_STDIO();
	fflush(stream);
	
	char*   line = GC_MALLOC(LINE_MAX);
	ssize_t reads;
	size_t  readn;
	while ((reads = getline(&line, &readn, stream)) > 0)
		fputs(line, yyout);

	pclose(stream);
}

#define OUTPUT_DELIM(ws) (fputws(ws, delim_stream))
#define XNAME_MAX 	 8

#ifdef __unix__
#define TMP_FMT "%s/%s"
#else
#define TMP_FMT "%s\\%s"
#endif

FILE*		delim_hold;
FILE*		delim_stream;
char		delim_fpath[XNAME_MAX + 1];
char		delim_rpath[FILENAME_MAX];
char*		delim_command;	


void init_delim_stream(wchar_t* text) {
	memset(&delim_fpath[0], 'X', XNAME_MAX);
	if (mkstemp(&delim_fpath[0]) < 0) {
		EEXIT(ERR_DELIM_FPATH, ECODE_DELIM_FPATH);
	}

	sprintf(&delim_rpath[0], TMP_FMT, P_tmpdir, &delim_fpath[0]);

	if (!(delim_stream = fopen(&delim_rpath[0], "w"))) {
		EEXIT(ERR_DELIM_OPEN, ECODE_DELIM_OPEN);
	}

	if (fputws(text, delim_stream) < 0) {
		EEXIT(ERR_DELIM_WRITE, ECODE_DELIM_WRITE);
	}

	delim_hold = stdin;
	if (dup2(fileno(delim_stream), STDIN_FILENO) < 0) {
		EEXIT(ERR_DELIM_DUP, ECODE_DELIM_DUP);
	}
	fclose(delim_stream);
	delim_hold = stdin;
	freopen(&delim_rpath[0], "r", stdin);
}

void exec_delim_command(void) {
	FILE* stream = popen(delim_command, "r");

	char*   line = GC_MALLOC(LINE_MAX);
	ssize_t reads;
	size_t  readn;
	while ((reads = getline(&line, &readn, stream)) > 0)
		fputs(line, yyout);

	stdin = delim_hold;
	pclose(stream);

}

#define  ARG_MAX	255
wchar_t* invoke_argv[ARG_MAX];
wchar_t* joined_argv;
size_t	 invoke_argc = 0;
size_t	 invoke_argn = 0;

void invoke_addarg(wchar_t* arg) {
	invoke_argv[invoke_argc++] = gc_wcsdup(arg);
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
}

void invoke_printargs(wchar_t* delim) {
	size_t n = 0;
	while (n < invoke_argc - 1) {
		OUTPUT(invoke_argv[n++]);
		OUTPUT(delim);
	}

	OUTPUT(invoke_argv[n]);
}

extern wchar_t* yybodyeval(wchar_t*);

void invoke_macro(wchar_t *id) {
	wchar_t* macro = get_symbol(id);
	if (!macro)
		macro = get_stack_value(id);
	if (!macro) {
		EEXIT(ERR_UNKNOWN_MACRO, ECODE_UNKNOWN_MACRO);
	}
	yybodyeval(macro);
	free(id);
}

wchar_t*	fmt;

void print_formatted(void) {
	wchar_t    wc;
	int        i    = 0;
	intmax_t   num;
	wchar_t*   str;

	while ((wc = *fmt++) && i < invoke_argc) {
		if (wc == L'%' && *fmt != L'%') {
			switch (*fmt++) {
				case L'd':
				case L'i':
				case L'l':
					num = 
					  wcstoimax(&invoke_argv[i++][0],
							NULL, 10);
					fwprintf(yyout, L"%ld", num);
					break;
				case L'x':
					num = 
					  wcstoimax(&invoke_argv[i++][0],
							NULL, 16);
					fwprintf(yyout, L"%x", num);
					break;
				case L'o':
					num = 
					   wcstoimax(&invoke_argv[i++][0],
							NULL, 8);
					fwprintf(yyout, L"%o", num);
					break;
				case L's':
					str = invoke_argv[i++];
					fwprintf(yyout, L"%s", str);
					break;
				default:
					break;
			} 
		}
		else
			fputwc(wc, yyout);
	}

}


void print_env(char* key) {
	char* var;
	if ((var = getenv(key)) != NULL)
		fputs(var, yyout);
}

extern char** sys_argv;
extern int    sys_argc;

void print_argv(int n) {
	if (sys_argc > n) {
		fputs(sys_argv[n], yyout);
	}
}

wchar_t*	aux_prim;
wchar_t*	aux_sec;
wchar_t*	aux_tert;

void set_aux(wchar_t** aux, wchar_t* value) {
	*aux = gc_wcsdup(value);
}

void translit(void) {
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
				fputwc(DSTMAP[offs], yyout);
			else
				break;
		} else
			fputwc(wc, yyout);
	}
	OUTPUT(&INPUT[++offs]);

	#undef INPUT
	#undef SRCMAP
	#undef DSTMAP
}

void offset(void) {
	#define INPUT		aux_prim
	#define SUB		aux_sec

	fwprintf(yyout, L"%lp", wcsstr(INPUT, SUB) - INPUT);

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
		fprintf(yyout, 
				"%d -- %s\n", 
				++i,
				&entry->d_name[0]
			);
		free(entry);
	}

	closedir(stream);

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

	fputs(&out_time[0], yyout);

	#undef FMT
}

void dnl(void) {
	fscanf(yyin, "%*s\n");
}

void do_on_exit(void) {
	free_set_diverts();
}

mbstate_t mbs;
wchar_t*  wcs;

#define SPACE		' '

wchar_t* gc_wcsdup(wchar_t* ws) {
	size_t		len = wcslen(ws) + 1;
	wchar_t*	wsc = GC_MALLOC(sizeof(wchar_t) * len);
	return memmove(&wsc[0], &ws[0], len * sizeof(wchar_t));
}

wchar_t* gc_mbsdup(const char* s) {
	memset(&mbs, 0, sizeof(mbstate_t));
	size_t len 	    = strlen(s) + 1;
	wchar_t*	wcs = GC_MALLOC(sizeof(wchar_t) * len);
	mbsrtowcs(wcs, &s, len, &mbs);
	return wcs;
}

char* gc_strdup(char* s) {
	size_t 		len = strlen(s) + 1;
	char*		wsc = GC_MALLOC(len);
	return memmove(&wsc[0], &s[0], len);
}


char* str_ltrim(char* str, int ch) {
	char* ret = str;
	while (strchr(ret, ch) != NULL)
		ret = &ret[1];
	return ret;
}

char* str_rtrim(char* str, int ch) {
	char* ret = str;
	while ((str = strrchr(ret, ch)) != NULL)
		ret[str - ret] = '\0';
	return ret;
}

wchar_t* wstr_ltrim(wchar_t* str, wchar_t ch) {
	wchar_t* ret = str;
	while (wcschr(ret, ch) != NULL)
		ret = &ret[1];
	return ret;
}

wchar_t* wstr_rtrim(wchar_t* str, wchar_t ch) {
	wchar_t* ret = str;
	while ((str = wcsrchr(str, ch)) != NULL)
		ret[str - ret] = '\0';
	return ret;
}


wchar_t* wstr_trim(wchar_t* str, wchar_t ch) {
	return wstr_ltrim(wstr_rtrim(str, ch), ch);
}

char*  str_trim(char* str, int ch) {
	return str_ltrim(str_rtrim(str, ch), ch);
}





