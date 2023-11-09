#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdlib.h>
#include <limits.h>
#include <mqueue.h>
#include <time.h>
#include <unistd.h>

#include <gc.h>
#include <unistr.h>
#include <libtcc.h>

#include "ekipp.h"
#include "templating.h"

TCCState* 	transpile_state 		= NULL;
FILE*		transpile_stream		= NULL;
char		transpile_path[FILENAME_MAX] 	= {0};

#ifdef __unix__
#define TEMPLATE	"%s/XXXXX"
#else
#define TEMPLATE	"%s\\XXXXX"

void transpile_run(void) {
	tcc_run(transpile_state, 0, NULL);
}

static void transpile_add_includes(void) {
	tcc_add_sysinclude_path(transpile_state, "mqueue.h");
	tcc_add_sysinclude_path(transpile_state, "stdio.h");
	tcc_add_sysinclude_path(transpile_state, "stdint.h");
	tcc_add_sysinclude_path(transpile_state, "stdlib.h");
	tcc_add_sysinclude_path(transpile_state, "string.h");
	tcc_add_sysinclude_path(transpile_state, "gc.h");
	tcc_add_sysinclude_path(transpile_state, "unistr.h");
}

static void transpile_add_libraries(void) {
	tcc_add_library(transpile_state, "unistring");
	tcc_add_library(transpile_state, "rt");
	tcc_add_library(transpile_state, "gc");
}
void init_transpile_state(void) {
	if (sprintf(&transpile_path[0], TEMPLATE, P_tmpdir) < 0) {
		EEXIT(ERR_FORMAT_DIRPATH, ECODE_FORMAT_DIRPATH);
	}

	if (mkstemp(&transpile_path[0]) < 0) {
		EEXIT(ERR_TMP_FILE, ECODE_TMP_FILE);
	}

	transpile_stream  = fopen(&transpile_path[0], "w+");
	transpile_state = tcc_new();
	
	tcc_add_file(transpile_state, &transpile_path[0]);
	tcc_set_output_type(transpile_state, TCC_OUTPUT_MEMORY);

	transpile_add_includes();
	transpile_add_libraries();

}

static void unlink_transpile_file(void) {
	unlink(&transpile_path[0]);
}



void reset_transpile_state(void) {
	if (transpile_state == NULL)
		return;
	tcc_delete(transpile_state);
	memset(&transpile_path, 0, FILENAME_MAX);
	transpile_stream = NULL;
}

void write_variable(char* type, char* name, char* init) {
	fprintf(transpile_stream, "%s %s = %s;", type, name);
}

void write_function(char* name, char* args, char* body) {
	fprintf(transpile_stream, "void %s (%s, void** __result){ %s; }",
			name, args, body);
}

void write_if(char* cond, char* body) {
	fprintf(transpile_stream, "if (%s) { %s; }", cond, body);
}

void write_elseif(char* cond, char* body) {
	fprintf(transpile_stream, "else if (%s) { %s; }", cond, body);
}

void write_else(char* body) {
	fprintf(transpile_stream, "else { %s; }", body);
}

void write_forloop(char* start, char* cond, char* step, char* body) {
	fprintf(transpile_stream, "for (%s;%s;%s) { %s; }",
			start, cond, step, body);
}

void write_whileloop(char* cond, char* body) {
	fprintf(transpile_stream, "while (%s) { %s; }", 
			cond, body);
}

void write_goto(char* label, char* after) {
	fprintf(transpile_stream, "%s: %s", label, after);
}

static struct TemplateSymTable {
	symtab_t*	next;
	uint8_t* 	name;
	void*		value;
	enum Symtype { INT, FLOAT, 
	   STR, PTR, }  type;
} *Symtable;


void tmpl_add_symbol(uint8_t* name, void* value, enum Symtype type) {
	symtab_t*	node 	= GC_MALLOC(sizeof(symtab_t));
	node			= Symtable;
	node->name		= gc_strdup(name);
	node->value		= gc_strdup(value);
	Symtable		= node;
}

void tmpl_get_symbol(uint8_t* name, void** value, enum Symtype* type) {
	for (symtab_t* node = Symtable;
			node != NULL;
			node = Symtable->next) {
		if (u8_strcmp(node->name, name)) {
			*value = node->value;
			*type  = node->type;
			return;
		}
	}

}

void tmpl_delete_symbol(uint8_t* name) {
	for (symtab_t* node = Symtable;
			node != NULL;
			node = Symtable->next) {
		if (u8_strcmp(node->name, name)) {
			node = NULL;
			return;
		}
	}
}

extern FILE* yyout;

static void notify_function(union sigval sigv) {
	struct mq_attr   attrs;
	uint8_t*         msgbuff  = NULL;
	mqd_t		 mqdf 	  = *((mqd_t*) sv.sival_ptr);

	if (mq_getattr(mqdf, &attrs) == -1) {
		EEXIT(ERR_MQUEUE_ATTRS, ECODE_MQUEUE_ATTRS);
	}

	msgbuff = GC_MALLOC(attrs.mq_msgsize);
	if (msgbuff == NULL) {
		EEXIT(ERR_MQUEUE_BUFF, ECODE_MQUEUE_BUFF);
	}

	if (mq_receive(mqdf, msgbuff, attrs.mq_msgsize, NULL) < 0) {
		EEXIT(ERR_MQUEUE_RECEIVE, ECODE_MQUEUE_RECEIVE);
	}

	fwrite(msgbuff, attrs.mq_msgsize, sizeof(uint8_t), yyout);
	msgbuff = NULL;
}

mqd_t	mqdf_msg;
struct  sigevent sigv;
char*	mq_fname[FILENAME_MAX] = {0};

#define MQFNAME_LEN		12

void random_fname(void) {
	int l = MQFNAME_LEN;
	while (--l) {
		mq_fname[l] = (time(NULL) % 65) + 32;
	}
}

void hook_notify_function_and_wait(void) {
	if ((mqdf_msg = mq_open(mq_fname, O_RDONLY)) < 0) {
		EEXIT(ERR_MQUEUE_OPEN, ECODE_MQUEUE_OPEN);
	}

	sigv.sigev_notify		= SIGEV_THREAD;
	sigv.sigev_notify_function	= notify_function;
	sigv.sigev_notify_attributes	= NULL;
	sigv.sigev_value.sival_ptr	= &mqdf_msg;

	if (mq_notify(mqdf_msg, &sigv) < 0) {
		EEXIT(ERR_MQUEUE_NOTIFY, ECODE_MQUEUE_NOTIFY);
	}

	pause();
}

void close_mqdf(void) {
	mq_close(mqdf_msg);
}

void write_notify_decl(void) {
	fprintf(transpile_stream, "mqd_t mqdf = 0;");
}

void write_notify_open(void) {
	fprintf(transpile_stream, 
		"mqdf = mq_open(%s, O_WRONLY);",
		mq_fname);
}

void write_notify_send(char* varname, int prio) {
	fprintf(transpile_stream,
		"mq_send(mqdf, %s, u8_strlen(%s), %d);",
		varname, varname, prio);
}

void write_notify_close(void) {
	fprintf(transpile_stream, "mq_close(mqdf);");
}


