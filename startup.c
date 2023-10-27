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


#define MAX_TOKEN  8

extern FILE*   yyin;
extern FILE*   output;
extern int     yyparse(void);
extern void    yyreflect(char* line);
extern void    do_on_exit(void);
extern char*   optarg;

extern char    quote_left[MAX_TOKEN];
extern char    quote_right[MAX_TOKEN];
extern char    comment_left[MAX_TOKEN];
extern char    comment_right[MAX_TOKEN];
extern char    delim_left[MAX_TOKEN];
extern char    delim_right[MAX_TOKEN];
extern char    argnum_sigil[MAX_TOKEN];
extern char    engage_sigil[MAX_TOKEN];
extern char    cond_sigil[MAX_TOKEN];
extern char    search_sigil[MAX_TOKEN];
extern char    aux_sigil[MAX_TOKEN];

static void close_io(void) {
	fflush(output);
	fclose(yyin);
	fclose(output);
}

void on_signal(int signum) {
	if (signum == SIGINT || signum == SIGTERM) {
		do_on_exit();
		close_io();
	}
}

static void on_startup(void) {
	atexit(do_on_exit);
	atexit(close_io);

	signal(SIGINT,  on_signal);
	signal(SIGTERM, on_signal);
}

static void repl(void) {
	char* line;
	while ((line = readline(NULL)) != NULL) {
		yyreflect(line);
		free(line);
	}
}

char**	sys_argv;
int	sys_argc;
char	input_path[FILENAME_MAX]  = {0};
char	output_path[FILENAME_MAX] = {0};


static void hook_io(void) {
	if (input_path[0] == 0 && isatty(STDIN_FILENO)) {
		repl();
		exit(EXIT_SUCCESS);
	}
	else if (input_path[0] == 0 && !isatty(STDIN_FILENO))
		yyin = stdin;
	else
		yyin = fopen(&input_path[0], "r");

	if (output_path[0] == 0)
		output = stdout;
	else
		output = fopen(&output_path[0], "w");
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

	while (true) {
		static char* short_options = 
			   "e::a::c::s::x::f::o::q::k::d::h";
		char* subopts;
		char* val;
		char* tok;

		static struct option long_options[] = {
			{ "aux-sigil",    required_argument, 0, 'x'},
			{ "search-sigil", required_argument, 0, 's'},
			{ "cond-sigil",   required_argument, 0, 'c'},
			{ "argnum-sigil", required_argument, 0, 'a'},
			{ "engage-sigil", required_argument, 0, 'e'},
			{ "delim-pair",   required_argument, 0, 'd'},
			{ "komment-pair", required_argument, 0, 'k'},
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
				continue;
			case 'a':
				set_token(&argnum_sigil[0], optarg);
				continue;
			case 'c':
				set_token(&cond_sigil[0], optarg);
				continue;
			case 's':
				set_token(&search_sigil[0], optarg);
				continue;
			case 'x':
				set_token(&aux_sigil[0], optarg);
				continue;
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
					case RIGHT:
						tok = c == 'q'
                                                   ? &quote_right[0]
						   : (c == 'k' 
							? &comment_right[0]
							: &delim_right[0]);
						set_token(&tok[0], val);
				continue;
			case 'f':
				strncpy(&input_path[0], 
						optarg,
						strlen(optarg));
				continue;
			case 'o':
				strncpy(&output_path[0], 
						optarg,
						strlen(optarg));
				continue;
			default:
				continue;
				}

		}

	}
}

int main(int argc, char** argv) {
	sys_argc = argc;
	sys_argv = argv;

	parse_options();
	hook_io();
	on_startup();

	if (yyparse())
		exit(EXIT_FAILURE);

	return EXIT_SUCCESS;
}
