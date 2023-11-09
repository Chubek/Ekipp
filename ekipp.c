#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <limits.h>
#include <string.h>
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

#include <unistr.h>
#include <unistdio.h>
#include <gc.h>

#include "ekipp.h"
#include "errors.gen"

#define EEXIT(e, c) do { fputs(e, stderr); exit(c);  } while (0)

static struct LinkedList {
	struct LinkedList*		next;
	char*				name;
	uint8_t*			value;
} *Symtable;

void insert_symbol(char* name, uint8_t* value) {
	node_t* 	node	= GC_MALLOC(sizeof(node_t));
	node->next		= Symtable;
	node->name		= gc_strdup(name);
	node->value    	 	= gc_strdup(value);
	Symtable		= node;
}

extern uint8_t* yydefeval(uint8_t* code);

void defeval_insert(char* name, uint8_t* code) {
	node_t*		node  = GC_MALLOC(sizeof(node_t));
	node->next	      = Symtable;
	node->name	      = gc_strdup(name);
	node->value	      = gc_strdup(yydefeval(code));
	Symtable	      = node;
}


uint8_t* get_symbol(char* name) {
	node_t* 	node;
	size_t 		len  = strlen(name);

	for (node = Symtable; node != NULL; node = node->next) {
		if (!strncmp(node->name, name, len))
			return node->value;
	}
	return NULL;
}


void remove_symbol(char* name) {
	node_t* 	node;
	size_t 		len  = strlen(name);

	for (node = Symtable; node != NULL; node = node->next) {
		if (!strncmp(node->name, name, len)) {
			GC_FREE(node);
		}
	}

}


#define MAX_STACK 	4096

static struct DefStack {
	char*		name;
	uint8_t*	value;
} Defstack[MAX_STACK];
size_t	stack_pointer = 0;

void push_stack(char* name, uint8_t* value) {
	Defstack[stack_pointer].name   = gc_strdup(name);
	Defstack[stack_pointer].value  = gc_strdup(value);
	stack_pointer++;
}

uint8_t* get_stack_value(char* name) {
	size_t len = strlen(name);
	size_t ptr = stack_pointer;

	while (--ptr) {
		if (!strncmp(Defstack[ptr].name, name, len))
			return Defstack[ptr].value;
	}

	return NULL;
}

uint8_t* pop_stack(void) {
	return Defstack[--stack_pointer].value;
}


#define NUM_DIVERT 	10

extern FILE*	yyout;

FILE*		divert_streams[NUM_DIVERT];
uint8_t*	divert_strings[NUM_DIVERT];
size_t		divert_lengths[NUM_DIVERT];
FILE*		current_divert;
DIR*		tmp_dir;
dev_t		null_dev;
int		null_fd;
FILE*		null_divert;
int		current_divert_idx;
FILE*		hold;

#define OUTPUT(us) 		(fputs(us, yyout))
#define OUTPUT_DIVERT(us) 	(fputs(us, current_divert))

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
				open_memstream((char**)&divert_strings[n],
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
				sizeof(uint8_t), yyout);
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
uint8_t*	reg_matchmsg;
uint8_t*	reg_nomatchmsg;

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
	char*    line_str;
	char*    word;
	size_t	 line_len;
	regoff_t start;
	regoff_t len;

	if (regcomp(&reg_cc, reg_pattern, 0) < 0) {
		EEXIT(ERR_REG_COMP, ECODE_REG_COMP);
	}

	for (;;) {
		if (getline(&line_str, &line_len, stream) > 0) {
			if (!regexec(&reg_cc, 
					line_str, 
					NMATCH, 
					reg_pmatch, 
					0)) {
				start = reg_pmatch[0].rm_so;
				len   = reg_pmatch[0].rm_eo - start;
				word = gc_strndup(&line_str[start], len);
				fputs(word, yyout);
				word = NULL;
			} else
				goto free;
		}
		free(line_str);
	}
free:
	regfree(&reg_cc);

}

void open_search_close(char* path) {
	FILE* stream;
	if ((stream = fopen(path, "r")) == NULL) {
		EEXIT(ERR_FILE_OPEN, ECODE_FILE_OPEN);
	}
	search_file(stream);
	fclose(stream);
}

extern FILE* yyin;

void yyin_search(void) {
	FILE* yyin_cpy = yyin;
	search_file(yyin_cpy);
}

#define FLUSH_STDIO() (fflush(stdin), fflush(stdout), fflush(stderr))

void ifelse_execmatch(uint8_t*		strcmp1,
                       uint8_t*		strcmp2,
		       char*   		cmdtrue,
		       char*		cmdfalse,
		       int flag) {
	int 	cmpres = u8_strcmp(strcmp1, strcmp2);
	char*	toexec = NULL;

	switch (flag) {
		case IFEXEC_EQ:
			!cmpres 
				? (toexec = cmdtrue)
				: (toexec = cmdfalse);
			goto exec;
		case IFEXEC_NE:
			cmpres
				? (toexec = cmdtrue)
				: (toexec = cmdfalse);
			goto exec;
		case IFEXEC_GE:
			cmpres >= 0
				? (toexec = cmdtrue)
				: (toexec = cmdfalse);
			goto exec;
		case IFEXEC_GT:
			cmpres > 0
				? (toexec = cmdtrue)
				: (toexec = cmdfalse);
			goto exec;
		case IFEXEC_LE:
			cmpres <= 0
				? (toexec = cmdtrue)
				: (toexec = cmdfalse);
			goto exec;
		case IFEXEC_LT:
			cmpres < 0
				? (toexec = cmdtrue)
				: (toexec = cmdfalse);
			goto exec;
		default:
			return;

			
	}
exec:
	exec_command(toexec);
}


void exec_command(char* exec_cmd) {
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

#define OUTPUT_DELIM(ws) (fputs(ws, delim_stream))
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


void init_delim_stream(uint8_t* text) {
	memset(&delim_fpath[0], 'X', XNAME_MAX);
	if (mkstemp(&delim_fpath[0]) < 0) {
		EEXIT(ERR_DELIM_FPATH, ECODE_DELIM_FPATH);
	}

	u8_sprintf(&delim_rpath[0], TMP_FMT, P_tmpdir, &delim_fpath[0]);

	if (!(delim_stream = fopen(&delim_rpath[0], "w"))) {
		EEXIT(ERR_DELIM_OPEN, ECODE_DELIM_OPEN);
	}

	if (fputs(text, delim_stream) < 0) {
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
uint8_t* invoke_argv[ARG_MAX];
uint8_t* joined_argv;
size_t	 invoke_argc = 0;
size_t	 invoke_argn = 0;

void invoke_addarg(uint8_t* arg) {
	invoke_argv[invoke_argc++] = gc_strdup(arg);
}

uint8_t* invoke_getarg(size_t n) {
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

void invoke_printrng(int from, int to) {
	int i = 0;
	for (i = from; i < to && i != invoke_argc; i++) {
		OUTPUT(invoke_argv[i]);
		OUTPUT(getenv("EKIPP_ARG_JOIN"));
	}
	OUTPUT(invoke_argv[i]);
}

void invoke_joinargs(uint8_t* delim) {
	size_t n = 0;
	size_t l = 0;
	size_t i = 0;
	while (n < invoke_argc - 1) {
		l = u8_strlen(invoke_argv[n]);
		u8_strncat(&joined_argv[i], &invoke_argv[n++][0], l);
		i += l;
	}
	l = u8_strlen(invoke_argv[++n]);
	u8_strncat(&joined_argv[i], &invoke_argv[n][0], l);
}

void invoke_printargs(uint8_t* delim) {
	size_t n = 0;
	while (n < invoke_argc - 1) {
		OUTPUT(invoke_argv[n++]);
		OUTPUT(delim);
	}

	OUTPUT(invoke_argv[n]);
}

uint8_t*	fmt;

void print_formatted(void) {
	uint8_t    wc;
	int        i    = 0;
	intmax_t   num;
	uint8_t*   str;

	while ((wc = *fmt++) && i < invoke_argc) {
		if (wc == '%' && *fmt != '%') {
			switch (*fmt++) {
				case 'd':
				case 'i':
				case 'l':
					num = 
					  strtoimax(&invoke_argv[i++][0],
							NULL, 10);
					fprintf(yyout, "%ld", num);
					break;
				case 'x':
					num = 
					  strtoimax(&invoke_argv[i++][0],
							NULL, 16);
					fprintf(yyout, "%lx", num);
					break;
				case 'o':
					num = 
					   strtoimax(&invoke_argv[i++][0],
							NULL, 8);
					fprintf(yyout, "%lo", num);
					break;
				case 's':
					str = invoke_argv[i++];
					fprintf(yyout, "%s", str);
					break;
				default:
					break;
			} 
		}
		else
			fputc(wc, yyout);
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

void translit(uint8_t* input, uint8_t* srcmap, uint8_t* dstmap) {
	uint8_t map[UINT8_MAX] = {0}, uc;
	for (size_t i = 0; i < strlen(srcmap); i++)
		map[srcmap[i]] = dstmap[i];

	while ((uc = *input++)) {
		if (map[uc])
			fputc(map[uc], yyout);
		else
			fputc(uc, yyout);
	}
}

void offset(uint8_t* input, uint8_t* sub) {
	fprintf(yyout, getenv("EKIPP_OFFS_FMT") 
			? getenv("EKIPP_OFFS_FMT")
			: "%ld\n", 
			u8_strstr(input, sub) - input);
}


void list_dir(char* dir_path) {
	DIR* stream = opendir(dir_path);
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
	}

	closedir(stream);
}


void cat_file(char* file_path) {
	FILE*	stream	= fopen(file_path, "r");
	if (stream == NULL) {
		EEXIT(ERR_OPEN_FILE, ECODE_OPEN_FILE);
	}

	if (fseek(stream, 0, SEEK_END) < 0) {
		EEXIT(ERR_CAT_FAIL, ECODE_CAT_FAIL);
	}

	long len = ftell(stream) + 1;
	if (len < 0) {
		fclose(stream);
		return;
	}

	rewind(stream);

	char* text = GC_MALLOC(len);
	if (fread(&text[0], len, sizeof(char), stream) < 0) {
		EEXIT(ERR_CAT_FAIL, ECODE_CAT_FAIL);
	}

	fputs(text, yyout);

	fclose(stream);
}

extern	int 	yyparse(void);

void include_file(char* file_path) { 
	FILE* inhold	= yyin;
	yyin		= fopen(file_path, "r");

	yyparse();

	fclose(yyin);
	yyin = inhold;
}

#define OUT_TIME_MAX (2 << 14)

void format_time(char* tfmt) {
	char   out_time[OUT_TIME_MAX] = {0};
	time_t t;
	struct tm* tmp;

	t 	= time(NULL);
	tmp 	= localtime(&t);
	if (tmp == NULL) {
		EEXIT(ERR_FORMAT_TIME, ECODE_FORMAT_TIME);
	}

	if (strftime(&out_time[0], OUT_TIME_MAX, tfmt, tmp) == 0) {
		EEXIT(ERR_FORMAT_TIME, ECODE_FORMAT_TIME);
	}

	fputs(&out_time[0], yyout);
}

void dnl(void) {
	fscanf(yyin, "%*s\n");
}

void do_on_exit(void) {
	free_set_diverts();
}

uint8_t* gc_strdup(uint8_t* s) {
	uint8_t*	sc  = NULL;
	size_t		len = u8_strlen(s);
	sc  		    = GC_MALLOC(sizeof(uint8_t) * (len + 1));
	return memmove(&sc[0], &s[0], len * sizeof(uint8_t));
}

uint8_t* gc_strndup(uint8_t* s, size_t len) {
	uint8_t*	sc  = GC_MALLOC(sizeof(uint8_t) * (len + 1));
	return memmove(&sc[0], &s[0], len * sizeof(uint8_t));
}


