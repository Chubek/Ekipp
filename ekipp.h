#ifndef EKIPP_H_
#define EKIPP_H_

#include <wchar.h>
#include <stdbool.h>
#include <sys/types.h>

#define IFEXEC_EQ       1
#define IFEXEC_NE       2
#define IFEXEC_GE       3
#define IFEXEC_GT       4
#define IFEXEC_LE       5
#define IFEXEC_LT       6

typedef struct LinkedList 	node_t;
typedef struct Defstack	  	dstack_t;

void insert_symbol(char* name, uint8_t* value); 
uint8_t* get_symbol(char* name); 
void free_node(node_t* node); 
void remove_symbol(char* name); 
void push_stack(char* name, uint8_t* value); 
void defeval_insert(char* name, uint8_t* code);
uint8_t* get_stack_value(char* name); 
uint8_t* pop_stack(void); 
void open_null_file(void); 
void destroy_null_divert(void); 
void set_divert(int n); 
void unset_divert(int n); 
void free_set_diverts(void); 
void switch_output(FILE* stream); 
void unswitch_output(void); 
void ifelse_regmatch(void); 
void search_file(FILE* stream); 
void open_search_close(char* path); 
void yyin_search(void); 
void ifelse_execmatch(uint8_t*, uint8_t*, char*, char*, int flag); 
void exec_command(char* exec_cmd); 
void init_delim_stream(uint8_t* text); 
void exec_delim_command(void); 
void zero_registry(void); 
void register_token(char* token); 
void set_token(char* token, char* value); 
void reformat_fmts(void); 
void invoke_addarg(uint8_t* arg); 
uint8_t* invoke_getarg(size_t n); 
void invoke_printnext(void); 
void invoke_printarg(size_t n); 
void invoke_printrng(int from, int to);
void invoke_printargs(uint8_t* delim); 
void invoke_joinargs(uint8_t* delim);
void invoke_macro(char* id); 
void foreach_macro(uint8_t* macro); 
void print_formatted(void); 
void print_env(char* key); 
void print_argv(int n); 
void set_aux(uint8_t** aux, uint8_t* value); 
void free_aux(uint8_t* aux); 
void translit(uint8_t* input, uint8_t* srcmap, uint8_t* dstmap); 
void offset(uint8_t* input, uint8_t* sub); 
void list_dir(char* dir_path); 
void cat_file(char* file_path); 
void include_file(char* file_path);
void format_time(char* tfmt); 
void dnl(void);
void do_on_exit(void);
uint8_t* gc_strdup(uint8_t* s);
uint8_t* gc_strndup(uint8_t*, size_t len);
void init_hold(void);

#endif
