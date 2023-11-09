#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdlib.h>
#include <limits.h>

#include <gc.h>
#include <unistr.h>
#include <libtcc.h>

#include "ekipp.h"


TCCState* 	transpile_state 		= NULL;
FILE*		transpile_stream		= NULL;
char		transpile_path[FILENAME_MAX] 	= {0};

#ifdef __unix__
#define TEMPLATE	"%s/XXXXX"
#else
#define TEMPLATE	"%s\\XXXXX"

void init_transpile_state(void) {
	if (sprintf(&transpile_path[0], TEMPLATE, P_tmpdir) < 0) {
		EEXIT(ERR_FORMAT_DIRPATH, ECODE_FORMAT_DIRPATH);
	}

	if (mkstemp(&transpile_path[0]) < 0) {
		EEXIT(ERR_TMP_FILE, ECODE_TMP_FILE);
	}

	transpile_stream  = fopen(&transpile_path[0], "w+");
	transpile_state = tcc_new();

}

void reset_transpile_state(void) {
	if (transpile_state == NULL)
		return;
	tcc_delete(transpile_state);
	memset(&transpile_path, 0, FILENAME_MAX);
	transpile_stream = NULL;
}

#define ARGUMENT_MAX 128

static struct FunctionSignature {
	enum ArgType {
		VOID = 1, UINT = 2, INT    = 3, 
		PTR  = 4,  STR = 5, STRUCT = 6,
	} return_type, 
		arg_types[ARGUMENT_MAX];
	char* 	arg_fields[ARGUMNET_MAX];
	char*	arg_names[ARGUMENT_MAX];
	char*	func_name;
	int	argc;
} FuncSig;
typedef enum ArgType argtype_t;

void reset_fnsig(void) {
	memset(FuncSig, 0, sizeof(FuncSig);
}

void addarg_fnsig(argtype_t type, char* name, char* fields) {
	FuncSig.arg_types[FnSignautre.argc]  = type;	
	FuncSig.arg_fields[FnSignautre.argc] = gc_strdup(fields);	
	FuncSig.arg_names[FnSignautre.argc]  = gc_strdup(name);	
	FuncSig.argc++;
}

void fnname_fnsig(char* name) {
	FuncSig.func_name = gc_strdup(name);
}

void retrtype_fnsig(argtype_t type) {
	FuncSig.return_type = type;
}

#define MAX_NAME 32

void argfld_fnsig(char* argfld) {
	char  chr     = 0;
	char* name[MAX_NAME + 1] = {0};
	int   printed = 0;
	char* retr = GC_MALLOC(strlen(argfld) * 2048);
	while ((chr = *argfld++)) {
		if (chr == '%') {
			memset(&name[0], 0, MAX_NAME + 1);
			switch(*argfld++) {
				case 'i':
					sscanf(&argfld[0], 
						 "%s;", &name[0]);
					printed = 
					   sprintf(&retr[printed],
						"long long %s;",
						&name[0]);
					break;
				case 'u':
					sscanf(&argfld[0], 
						"%s;", &name[0]);
					printed = 
					   sprintf(&retr[printed],
						"unsigned long long %s;",
						&name[0]);
					break;
				case 's':
					sscanf(&argfld[0], 
						"%s;", &name[0]);
					printed = 
					   sprintf(&retr[printed],
						"unsigned char* %s;",
						&name[0]);
					break;
				case 'v':
					sscanf(&argfld[0],
						"%s;", &name[0]);
					printed = 
					   sprintf(&retr[printed],
						"void* %s;",
						&name[0]);
					break;
				default:
					break;

			}
		}
	}
	return retr;
}

static char* typefmt_map[] = {
	"void %s", "unsigned long long %s", "long long %s"
	"void* %s"  "unsigned char* %s",    "struct { %s } %s",
};

void serialize_fnsig(void) {
	fputc('\n', transpile_stream);
	fprintf(transpile_stream, typefmt_map[FuncSig.return_type],
		FuncSig.func_name);
	fputc('(', transpile_stream);
	int i = 0;
	while (i < FuncSig.argc) {
		fprintf(transpile_stream,
				typefmt_map[FnSignautre.arg_type[i]],
				FuncSig.arg_fields[i] 
				  ? argfld_fnsig(FuncSig.arg_fields[i])
				  : " ",
				FuncSig.arg_names[i++]);
		if (i + 1 != FuncSig.argc)
			fputc(',', transple_file);
	}
	fputc(')', transpile_stream);
}

void invoke




