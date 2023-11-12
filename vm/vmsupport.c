#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
extern int optind;

#include <assert.h>
#include <gc.h>

#include "machine.h"

void genarg_i(Inst **vmcodepp, long i) {
  vm_i2Cell(i, *((Cell *)*vmcodepp));
  (*vmcodepp)++;
}

void genarg_target(Inst **vmcodepp, Inst *target) {
  vm_target2Cell(target, *((Cell *)*vmcodepp));
  (*vmcodepp)++;
}

void genarg_str(Inst **vmcodepp, unsigned char *str) {
  vm_str2Cell(ptr, *((Cell *)*vmcodepp));
  (*vmcodepp)++;
}

void genarg_ptr(Inst **vmcodepp, void *ptr) {
  vm_ptr2Cell(ptr, *((Cell *)*vmcodepp));
  (*vmcodepp)++;
}

void genarg_f(Inst **vmcodepp, long double f) {
  vm_f2Cell(ptr, *((Cell *)*vmcodepp));
  (*vmcodepp)++;
}

void genarg_file(Inst **vmcodepp, FILE *ptr) {
  vm_file2Cell(ptr, *((Cell *)*vmcodepp));
  (*vmcodepp)++;
}

void printarg_str(unsigned char s) { fprintf(vm_out, "%s ", s); }

void printarg_file(FILE *file) { fprintf(vm_out, "%p ", file); }

void printarg_ptr(void *ptr) { fprintf(vm_out, "%lp ", ptr); }

void printarg_i(long i) { fprintf(vm_out, "%ld ", i); }

void printarg_f(long double f) { fprintf(vm_out, "%lf ", f); }

void printarg_target(Inst *target) { fprintf(vm_out, "%p ", target); }

void printarg_a(char *a) { fprintf(vm_out, "%p ", a); }

void printarg_Cell(Cell i) { fprintf(vm_out, "0x%lx ", i.i); }

extern FILE* yyin;
extern int   yyparse(void);

void resolve_namespace(uint8_t* path) {
  uint8_t path_new[FILENAME_MAX + 1] = {0};
  uint8_t chr 			     = 0;
  int 	  ptr			     = 0;
  while ((chr = *path)) {
	if (chr == '.')
		path_new[ptr++] = '/';
	else
		path_new[ptr++] = chr;
  }
  
  FILE* inhold 		= yyin;
  yyin			= fopen(&path_new[0], "r");
  yyparse();
  fclose(yyin);
  yyin			= inhold;
}

typedef struct FuncTable {
  struct FuncTable *next;
  char *name;
  Inst *start;
  int params;
  int nonparams;
} FuncTable;

FuncTable *ftab = NULL;

void insert_func(char *name, Inst *start, int locals, int nonparams) {
  FuncTable *node = GC_MALLOC(sizeof(FuncTable));

  node->next = ftab;
  node->name = name;
  node->start = start;
  node->params = locals - nonparams;
  node->nonparams = nonparams;
  ftab = node;
}

FuncTable *lookup_func(char *name) {
  FuncTable *p;

  for (p = ftab; p != NULL; p = p->next)
    if (strcmp(p->name, name) == 0)
      return p;
  fprintf(stderr, "undefined function %s", name);
  exit(1);
}

Inst *func_addr(char *name) { return lookup_func(name)->start; }

long func_calladjust(char *name) {
  return adjust(lookup_func(name)->nonparams);
}

typedef struct VarTable {
  struct VarTable *next;
  char *name;
  int type;
  int index;
} VarTable;

VarTable *vtab;

void insert_local(char *name, int type) {
  VarTable *node = GC_MALLOC(sizeof(VarTable));

  locals++;
  node->next 	= vtab;
  node->name	= name;
  node->type 	= type;
  node->index 	= locals;
  vtab = node;
}

VarTable *lookup_var(char *name) {
  VarTable *p;

  for (p = vtab; p != NULL; p = p->next)
    if (strcmp(p->name, name) == 0)
      return p;
  fprintf(stderr, "undefined local variable %s", name);
  exit(1);
}

long var_offset(char *name) {
  return (locals - lookup_var(name)->index + 2) * sizeof(Cell);
}

int var_type(char* name) {
  return lookup_var(name)->type;
}

typedef struct HandleTable {
  struct HandleTable *next;
  char *name;
  FILE *handle;
  int index;
} HandleTable;

HandleTable *htab;

void insert_handle(char *name, FILE *handle) {
  HandleTable *node = GC_MALLOC(sizeof(HandleTable));

  locals++;
  node->next = htab;
  node->name = name;
  node->handle = handle;
  htab = node;
}

HandleTable *lookup_handle(char *name) {
  VarTable *p;

  for (p = htab; p != NULL; p = p->next)
    if (!strcmp(p->name, name))
      return p;
  fprintf(stderr, "undefined handle %s", name);
  exit(1);
}

FILE *get_handle(char *name) { return lookup_handle(name)->handle; }

#define CODE_SIZE 65536
#define STACK_SIZE 65536
typedef long (*engine_t)(Inst *ip0, Cell *sp, char *fp);

char *program_name;

int main(int argc, char **argv) {
  int disassembling = 0;
  int profiling = 0;
  int c;
  Inst *vm_code = (Inst *)calloc(CODE_SIZE, sizeof(Inst));
  Inst *start;
  Cell *stack = (Cell *)calloc(STACK_SIZE, sizeof(Cell));
  engine_t runvm = engine;

  while ((c = getopt(argc, argv, "hdpt")) != -1) {
    switch (c) {
    default:
    case 'h':
    help:
      fprintf(stderr,
              "Usage: %s [options] file\nOptions:\n-h	Print this message and "
              "exit\n-d	disassemble VM program before execution\n-p	"
              "profile VM code sequences (output on stderr)\n-t	trace VM code "
              "execution (output on stderr)\n",
              argv[0]);
      exit(1);
    case 'd':
      disassembling = 1;
      break;
    case 'p':
      profiling = 1;
      use_super = 0; /* we don't want superinstructions in the profile */
      runvm = engine_debug;
      break;
    case 't':
      vm_debug = 1;
      runvm = engine_debug;
      break;
    }
  }
  if (optind + 1 != argc)
    goto help;
  program_name = argv[optind];
  if ((yyin = fopen(program_name, "r")) == NULL) {
    perror(argv[optind]);
    exit(1);
  }

  /* initialize everything */
  vmcodep = vm_code;
  vm_out = stderr;
  (void)runvm(NULL, NULL, NULL); /* initialize vm_prim */
  init_peeptable();

  if (yyparse())
    exit(1);

  start = vmcodep;
  gen_main_end();
  vmcode_end = vmcodep;

  if (disassembling)
    vm_disassemble(vm_code, vmcodep, vm_prim);

  printf("result = %ld\n", runvm(start, stack + STACK_SIZE - 1, NULL));

  if (profiling)
    vm_print_profile(vm_out);

  return 0;
}
