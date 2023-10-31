#include <unistd.h>
#include <getopt.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <signal.h>
#include <limits.h>
#include <sys/sysmacros.h>
#include <readline/readline.h>
#include <readline/history.h>

#include "ekipp.h"

#include <gc.h>

#define MAX_TOKEN  8

extern FILE*   yyin;
extern FILE*   yyout;
extern FILE*   output;
extern int     yyparse(void);
extern void    yyreflect(wchar_t* line);
extern char*   optarg;


extern char    quote_left[MAX_TOKEN];
extern char    quote_right[MAX_TOKEN];
extern char    comment_left[MAX_TOKEN];
extern char    comment_right[MAX_TOKEN];
extern char    delim_left[MAX_TOKEN];
extern char    delim_right[MAX_TOKEN];
extern char    engage_sigil[MAX_TOKEN];

static void close_io(void) {
	fflush(output);
	fclose(yyin);
	fclose(output);
}

void do_on_signal(int signum) {
	if (signum == SIGINT || signum == SIGTERM) {
		do_on_exit();
		close_io();
	}
}

static void on_startup(void) {
	yyout = output;

	atexit(do_on_exit);
	atexit(close_io);

	signal(SIGINT,  do_on_signal);
	signal(SIGTERM, do_on_signal);
}

static void repl(void) {
	char* line;
	while ((line = readline(NULL)) != NULL) {
		yyreflect((wchar_t*)line);
		free(line);
	}
}

char**	sys_argv;
int	sys_argc;
char	output_path[FILENAME_MAX] = {0};
char    input_files[FILENAME_MAX][MAX_INPUT] = {0};


static void hook_io(void) {
	if (input_files[0][0] == 0 && isatty(STDIN_FILENO)) {
		repl();
		exit(EXIT_SUCCESS);
	}
	else if (input_files[0][0] == 0 && !isatty(STDIN_FILENO))
		yyin = stdin;
	else
		yyin = fopen(&input_files[0][0], "r");

	if (output_path[0] == 0)
		output = stdout;
	else
		output = fopen(&output_path[0], "w");
}

#define LQUOTE_DFL 		"q/"
#define RQUOTE_DFL 		"/"
#define LCOMMENT_DFL		"/*"
#define RCOMMENT_DFL		"*/"
#define LDELIM_DFL		"<:?"
#define RDELIM_DFL		":?>"
#define ENGAGE_SIGIL_DFL	"#!"


static void set_default(void) {
	set_token(&quote_left[0], 
			getenv("EKIPP_LQUOTE") 
				? getenv("EKIPP_LQUOTE")
				: LQUOTE_DFL);
	set_token(&quote_right[0], 
			getenv("EKIPP_RQUOTE") 
				? getenv("EKIPP_RQUOTE")
				: RQUOTE_DFL);

	set_token(&comment_left[0], 
			getenv("EKIPP_LCOMMENT") 
				? getenv("EKIPP_LCOMMENT")
				: LCOMMENT_DFL);
	set_token(&comment_right[0], 
			getenv("EKIPP_RCOMMENT") 
				? getenv("EKIPP_RCOMMENT")
				: RCOMMENT_DFL);

	set_token(&delim_left[0], 
			getenv("EKIPP_LDELIM") 
				? getenv("EKIPP_LDELIM")
				: LDELIM_DFL);
	set_token(&delim_right[0], 
			getenv("EKIPP_RDELIM") 
				? getenv("EKIPP_RDELIM")
				: RDELIM_DFL);

	set_token(&engage_sigil[0],
			getenv("EKIPP_ENGAGE_SIGIL")
				? getenv("EKIPP_ENGAGE_SIGIL")
				: ENGAGE_SIGIL_DFL);

}

static void parse_options(void) {
	int	c;
	enum {
		LEFT = 0, RIGHT = 1,
	};

	char* const token[] = {
		[LEFT] 	= "l:",
		[RIGHT]	= "r:",
		NULL,
	};
	int inidx = 0;

	while (true) {
		static char* short_options = 
			   "e:a:c:s:x:f:o:q:k:d:h";
		char* subopts;
		char* val;
		char* tok;

		static struct option long_options[] = {
			{ "engage-sigil", required_argument, 0, 'e'},
			{ "delim-pair",   required_argument, 0, 'd'},
			{ "comment-pair", required_argument, 0, 'k'},
			{ "quote-pair",   required_argument, 0, 'q'},
			{ "input-script", required_argument, 0, 'f'},
			{ "output-file",  required_argument, 0, 'o'},
			{ "help",	  no_argument,       0, 'h'},
			{ 0,              0,                 0,  0 }

		};

		if ((c = getopt_long(sys_argc, 
					sys_argv, 
					short_options,
					long_options,
					NULL
				)) < 0)
			break;

		switch (c) {
			case 'e':
				set_token(&engage_sigil[0], optarg);
				break;
			case 'f':
				optind--;
				for (; optind < sys_argc 
					  && *sys_argv[optind] != '-';
					  optind++)
					strcpy(&input_files[inidx++][0],
						&sys_argv[optind][0]);
				break;
			case 'o':
				strncpy(&output_path[0], 
						optarg,
						strlen(optarg));
				break;
			case 'q':
			case 'k':
			case 'd':
				subopts = optarg;
				switch (getsubopt(&subopts, 
							token, &val)){
					case LEFT:
						tok = c == 'q'
                                                   ? &quote_left[0]
						   : (c == 'k' 
							? &comment_left[0]
							: &delim_left[0]);
						set_token(&tok[0], val);
						break;
					case RIGHT:
						tok = c == 'q'
                                                   ? &quote_right[0]
						   : (c == 'k' 
							? &comment_right[0]
							: &delim_right[0]);
						set_token(&tok[0], val);
						break;
				break;
			default:
				break;
				}

		}

	}
}

int main(int argc, char** argv) {
	GC_INIT();

	sys_argc = argc;
	sys_argv = argv;
	
	set_default();
	parse_options();
	hook_io();
	on_startup();

	if (yyparse())
		exit(EXIT_FAILURE);

	return EXIT_SUCCESS;
}
