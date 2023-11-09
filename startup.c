#include <unistd.h>
#include <getopt.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <signal.h>
#include <limits.h>
#include <sysexits.h>
#include <sys/sysmacros.h>
#include <readline/readline.h>
#include <readline/history.h>

#include <unistr.h>
#include <gc.h>

#include "ekipp.h"

#define MAX_TOKEN  8

extern char*     optarg;
extern FILE*	 yyin;
extern FILE* 	 yyout;
extern int	 yyparse(void);
extern uint8_t*  yydefeval(uint8_t*);

static uint8_t* yyreflect(const char* input) {
	size_t   	len = u8_strlen(input);
	uint8_t* 	wcs = GC_MALLOC(len * sizeof(uint8_t));

	return yydefeval(wcs);
}


static void close_io(void) {
	fflush(yyout);
	fclose(yyin);
	fclose(yyout);
}

void do_on_signal(int signum) {
	if (signum == SIGINT || signum == SIGTERM) {
		do_on_exit();
		close_io();
	}
}

static void on_startup(void) {
	atexit(do_on_exit);
	atexit(close_io);

	setenv("EKIPP_ARG_JOIN", ", ", false);
	
	signal(SIGINT,  do_on_signal);
	signal(SIGTERM, do_on_signal);
}

static void repl(void) {
	char* line = NULL;
	while ((line = readline(NULL)) != NULL) {
		yyreflect(line);
		free(line);
	}
}

char**	sys_argv;
int	sys_argc;
char	yyout_path[FILENAME_MAX] = {0};
char    input_files[FILENAME_MAX][MAX_INPUT] = {0};
int 	inidx = 0;


#define INCLUDE_PATHS_SEP ":"

static void add_includes(void) {
	char* includes = getenv("EKIPP_INCLUDE_PATHS");
	if (!includes)
		return;
	for (uint8_t* tok = strtok(includes, INCLUDE_PATHS_SEP); 
			tok != NULL; 
			tok = strtok(NULL, INCLUDE_PATHS_SEP)) {
		strncpy(&input_files[inidx++][0], &tok[0], strlen(tok));
	}
}

static void show_cc(void) {
	puts("Ekipp Copyright (C) 2023 Chubak Bidpaa");
	puts("This program comes with ABSOLUTELY NO WARRANTY\n");
}

static void hook_io(void) {
	if (input_files[0][0] == 0 && isatty(STDIN_FILENO)) {
		yyout = stdout;
		show_cc(); repl();
		exit(EXIT_SUCCESS);
	}
	else if (input_files[0][0] == 0 && !isatty(STDIN_FILENO))
		yyin = stdin;
	else {
		yyin = fopen(&input_files[0][0], "r");
		if (!yyin) {
			fprintf(stderr, "Error: file \"%s\" not found\n", 
					&input_files[0][0]);
			exit(EX_IOERR);
		}
	}
	if (yyout_path[0] == 0)
		yyout = stdout;
	else
		yyout = fopen(&yyout_path[0], "w");
}

static void parse_options(void) {
	int c;

	while (true) {
		static char* short_options =  "f:o:h";

		static struct option long_options[] = {
			{ "input-scripts", required_argument, 0, 'f'},
			{ "out-file",   required_argument, 0, 'o'},
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
			case 'f':
				optind--;
				for (; optind < sys_argc 
					  && *sys_argv[optind] != '-';
					  optind++)
					strcpy(&input_files[inidx++][0],
						&sys_argv[optind][0]);
				break;
			case 'o':
				strncpy(&yyout_path[0], 
						optarg,
						strlen(optarg));
				break;
			case 'h':
				printf("Usage: %s [-f INFILES...] [-o OUTFIULE]\n", sys_argv[0]);
				puts("Please see `man 1 ekipp` for more info.");
				exit(EXIT_FAILURE);
			default:
				break;
		}

	}
}

int main(int argc, char** argv) {
#ifndef __x86_64__
	GC_INIT();
#endif
	sys_argc = argc;
	sys_argv = argv;
	
	parse_options();
	hook_io();
	init_hold();
	on_startup();

	if (yyparse()) {
		putchar('\n');
		exit(EXIT_FAILURE);
	}

	putchar('\n');
	return EXIT_SUCCESS;
}
