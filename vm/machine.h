#ifndef MACHINE_H_
#define MACHINE_H_

#include <stdio.h>
#include <stdint.h>
#include <dlfcn.h>
#include <math.h>
#include <limits.h>
#include <ffi.h>
#include <sysexits.h>

#include <gc.h>
#include <unistr.h>
#include <unistdio.h>

#include "ekipp.h"

#ifdef __GNUC__
typedef void *Label; 
#else
typedef long Label;
#endif

typedef struct ExternalCall {
	void** 		arg_values;
	ffi_type**	arg_types;
	ffi_type	retrtype;
	int64_t		arg_integers[UINT8_MAX + 1];
	long double	arg_floats[UINT8_MAX + 1];
	uint8_t*	arg_strings[UINT8_MAX + 1];
	ffi_arg*	result;
	void*		exfn;
	int		argc;
} ExternCallIf;

typedef union Cell {
  long 			i;
  union Cell*		target;
  Label 		inst;
  char*			a;
  long double		f;
  unsigned char* 	str;
  FILE*			file;
  void* 		ptr;
} Cell, 		Inst;

#define vm_Cell2i(_cell,_x)		((_x)=(_cell).i)
#define vm_i2Cell(_x,_cell)		((_cell).i=(_x))
#define vm_Cell2f(_cell,_x)		((_x)=(_cell).f)
#define vm_f2Cell(_x,_cell)		((_cell).f=(_x))
#define vm_Cell2file(_cell,_x)		((_x)=(_cell).file)
#define vm_file2Cell(_x,_cell)		((_cell).file=(_x))
#define vm_Cell2str(_cell,_x)		((_x)=(_cell).str)
#define vm_str2Cell(_x,_cell)		((_cell).str=(_x))
#define vm_Cell2ptr(_cell,_x)		((_x)=(_cell).ptr)
#define vm_ptr2Cell(_x,_cell)		((_cell).ptr=(_x))	
#define vm_Cell2target(_cell,_x) 	((_x)=(_cell).target)
#define vm_target2Cell(_x,_cell) 	((_cell).target=(_x))	
#define vm_Cell2a(_cell,_x)		((_x)=(_cell).a)
#define vm_a2Cell(_x,_cell)		((_cell).a=(_x))	
#define vm_Cell2Cell(_x,_y) 		((_y)=(_x))

/* for future extensions */
#define IMM_ARG(access,value)		(access)

#define VM_IS_INST(_inst, n) ((_inst).inst == vm_prim[n])

extern Label *vm_prim;
extern int locals;
extern struct Peeptable_entry **peeptable;
extern int vm_debug;
extern FILE *yyin;
extern int yylineno;
extern char *program_name;
extern FILE *vm_out;
extern Inst *vmcodep;
extern Inst *last_compiled;
extern Inst *vmcode_end;
extern int use_super;
extern FILE* yyout;
extern ExternCallIf* ExternCall;

/* generic vmgen support functions (e.g., wrappers) */
void gen_inst(Inst **vmcodepp, Label i);
void init_peeptable(void);
void vm_disassemble(Inst *ip, Inst *endp, Label prim[]);
void vm_count_block(Inst *ip);
struct block_count *block_insert(Inst *ip);
void vm_print_profile(FILE *file);

/* ekipp type-specific support functions */
void genarg_i(Inst **vmcodepp, long i);
void genarg_ptr(Inst **vmcodepp, void* ptr);
void genarg_f(Inst **vmcodepp, long double f);
void genarg_str(Inst **vmcodepp, uint8_t* str);
void genarg_file(Inst **vmcodepp, FILE* file);
void genarg_ptr(Inst **vmcodepp, void* ptr);
void genarg_target(Inst **vmcodepp, Inst *target);
void printarg_i(long i);
void printarg_target(Inst *target);
void printarg_ptr(void *ptr);
void printarg_a(char *a);
void printarg_file(FILE* file);
void printarg_f(long double f);
void printarg_str(uint8_t* str);
void printarg_Cell(Cell i);

/* engine functions (type not fixed) */
long engine(Inst *ip0, Cell *sp, char *fp);
long engine_debug(Inst *ip0, Cell *sp, char *fp);

/* other generic functions */
int yyparse(void);

/* ekipp-specific functions */
void resolve_namespace(uint8_t* path);
void  insert_func(char* name, Inst* start, 
			int locals, int nonparams, int retrtype);
Inst* func_addr(char* name);
int   func_retrtype(char* name);
long  func_calladjust(char *name);
void  insert_local(char* name, int type);
long  var_offset(char* name);
int   var_type(char* name);
void  insert_handle(char* name, FILE *handle);
FILE* get_handle(char* name);
void  gen_main_end(void);
void  init_vm(void);
void  execute_vm(int profiling, int disassembling);


void zero_out_externif(void);
void init_externif(void);
void add_arg_externif(int arg_type, void* argval);

/* stack pointer change for a function with n nonparams */
#define adjust(n)  ((n) * -sizeof(Cell))

#define VAR_INT		1
#define VAR_STR		2
#define VAR_FLOAT	3
#define VAR_HANDLE	4
#define VAR_SYMBOL	5

#endif
