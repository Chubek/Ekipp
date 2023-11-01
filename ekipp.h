#ifndef EKIPP_H_
#define EKIPP_H_

#include <wchar.h>
#include <stdbool.h>
#include <sys/types.h>


typedef struct LinkedList 	node_t;
typedef struct Defstack	  	dstack_t;

void insert_symbol(wchar_t* name, wchar_t* value); 
wchar_t* get_symbol(wchar_t* name); 
void free_node(node_t* node); 
void remove_symbol(wchar_t* name); 
void push_stack(wchar_t* name, wchar_t* value); 
wchar_t* get_stack_value(wchar_t* name); 
wchar_t* pop_stack(void); 
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
void ifelse_execmatch(void); 
void exec_command(void); 
void init_delim_stream(wchar_t* text, size_t len); 
void exec_delim_command(void); 
void zero_registry(void); 
void register_token(char* token); 
void set_token(char* token, char* value); 
void reformat_fmts(void); 
void invoke_addarg(wchar_t* arg); 
wchar_t* invoke_getarg(size_t n); 
void invoke_printnext(void); 
void invoke_printarg(size_t n); 
void invoke_printargs(wchar_t* delim); 
void invoke_joinargs(wchar_t* delim);
void invoke_macro(wchar_t *id); 
void foreach_macro(wchar_t* macro); 
void print_formatted(void); 
void print_env(char* key); 
void print_argv(int n); 
void set_aux(wchar_t** aux, wchar_t* value); 
void free_aux(wchar_t* aux); 
void translit(void); 
void offset(void); 
void list_dir(void); 
void cat_file(void); 
void include_file(void);
void format_time(void); 
void dnl(void);
void do_on_exit(void);
wchar_t* gc_wcsdup(wchar_t* s);
wchar_t* gc_mbsdup(char* s);
char*	 gc_strdup(char* s);
void init_hold(void);

#endif
