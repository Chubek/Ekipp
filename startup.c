#include <unistd.h>
#include <getopt.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <signal.h>
#include <limits.h>
#include <readline/readline.h>
#include <readline/history.h>

#include "ekipp.h"

#define External   extern
#define Local	   static 

#define MAX_TOKEN  8

External FILE*	   yyin;
External FILE*     output;
External int  	   yyparse(void);
External void	   yyreflect(char* line);
External void 	   do_on_exit(void);
External char*	   optarg;

External   char    quote_left[MAX_TOKEN];
External   char    quote_right[MAX_TOKEN];
External   char    comment_left[MAX_TOKEN];
External   char    comment_right[MAX_TOKEN];
External   char    delim_left[MAX_TOKEN];
External   char    delim_right[MAX_TOKEN];
External   char    argnum_sigil[MAX_TOKEN];
External   char    engage_sigil[MAX_TOKEN];
External   char    cond_sigil[MAX_TOKEN];
External   char    search_sigil[MAX_TOKEN];
External   char    aux_sigil[MAX_TOKEN];

Local void close_io(void) {
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

Local void on_startup(void) {
	atexit(do_on_exit);
	atexit(close_io);

	signal(SIGINT,  on_signal);
	signal(SIGTERM, on_signal);
}

Local void repl(void) {
	char* line;
	while ((line = readline(NULL)) != NULL) {
		yyreflect(line);
		free(line);
	}
}

char**	sys_argv;
int	sys_argc;
char	input_path[MAX_FILEPATH]  = {0};
char	output_path[MAX_FILEPATH] = {0};


Local void hook_io(void) {
	if (&input_path[0] == "" && isatty(STDIN_FILENO))
		repl();
	else if (&input_path[0] == "" && !isatty(STDIN_FILENO))
		yyin = stdin;
	else
		yyin = fopen(&input_path[0], "r");

	if (&output_path[0] == "")
		output = stdout;
	else
		output = fopen(&output_path[0], "w");
}



Local void parse_options(void) {
	int	c;
	enum {
		LEFT = 0, RIGHT
	}

	char* const token[] = {
		[LEFT] 	= "l:",
		[RIGHT]	= "r:",
		NULL,
	}

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
				set_token(&engage_sigil, optarg);
				continue;
			case 'a':
				set_token(&argnum_sigil, optarg);
				continue;
			case 'c':
				set_token(&cond_sigil, optarg);
				continue;
			case 's':
				set_token(&search_sigil, optarg);
				continue;
			case 'x':
				set_token(&aux_sigil, optarg);
				continue;
			case 'q':
			case 'k':
			case 'd':
				subopts = optarg;
				switch (getsubopt(&subopts, 
							token, &val)){
					case LEFT:
						tok = c == 'q'
                                                   ? &quote_left
						   : (c == 'k' 
							? &comment_left
							: delim_left);
					case RIGHT:
						tok = c == 'q'
                                                   ? &quote_right
						   : (c == 'k' 
							? &comment_right
							: delim_right);
					set_token(tok, val);
				continue;
			case 'f':
				strcpy(&input_path[0], optarg);
				continue;
			case 'o':
				strcpy(&output_path[0], optarg);
				continue;
			default:
				continue;
				}

		}

	}
}
