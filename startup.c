#include <unistd.h>
#include <getopt.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <signal.h>

#define External   extern
#define Local	   static 

#define MAX_TOKEN  8

External int  	   yyparse(void);
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

void on_signal(int signum) {
	if (signum == SIGINT || signum == SIGTERM)
		do_on_exit();
}

Local void on_startup(void) {
	atexit(do_on_exit);

	signal(SIGINT,  on_signal);
	signal(SIGTERM, on_signal);
}

char**	sys_argv;
int	sys_argc;



Local void parse_options(void) {
	int	c;

	while (true) {
		static char* short_options = 
			   "e::a::c::s::x::f::o::q::k::d::h";

		static struct option long_options[] = {
			{ "aux-sigil",    optional_argument, 0, 'x'},
			{ "search-sigil", optional_argument, 0, 's'},
			{ "cond-sigil",   optional_argument, 0, 'c'},
			{ "argnum-sigil", optional_argument, 0, 'a'},
			{ "engage-sigil", optional_argument, 0, 'e'},
			{ "delim-pair",   optional_argument, 0, 'd'},
			{ "komment-pair", optional_argument, 0, 'k'},
			{ "quote-pair",   optional_argument, 0, 'q'},
			{ "input-script", optional_argument, 0, 'f'},
			{ "output-file",  optional_argument, 0, 'o'},
			{ "help",	  optional_argument, 0, 'h'},
			{ 0, 0, 0, 0				   }

		};

	}
}
