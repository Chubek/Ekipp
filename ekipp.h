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

void insert_symbol(char* name, wchar_t* value); 
wchar_t* get_symbol(char* name); 
void free_node(node_t* node); 
void remove_symbol(char* name); 
void push_stack(char* name, wchar_t* value); 
void defeval_insert(char* name, wchar_t* code);
wchar_t* get_stack_value(char* name); 
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
void ifelse_execmatch(wchar_t*, wchar_t*, char*, char*, int flag); 
void exec_command(char* exec_cmd); 
void init_delim_stream(wchar_t* text); 
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
void invoke_macro(char* id); 
void foreach_macro(wchar_t* macro); 
void print_formatted(void); 
void print_env(char* key); 
void print_argv(int n); 
void set_aux(wchar_t** aux, wchar_t* value); 
void free_aux(wchar_t* aux); 
void translit(uint8_t* input, uint8_t* srcmap, uint8_t* dstmap); 
void offset(wchar_t* input, wchar_t* sub); 
void list_dir(char* dir_path); 
void cat_file(char* file_path); 
void include_file(char* file_path);
void format_time(char* tfmt); 
void dnl(void);
void do_on_exit(void);
wchar_t* gc_wcsdup(wchar_t* s);
wchar_t* gc_mbsdup(const char* s);
char*	 gc_strdup(char* s);
char*    gc_wcs2mbs(wchar_t* s);
uint8_t* gc_ubydup(char* s);
char*	 gc_strndup(char* s, size_t len);
char*    str_trim(char* str, int ch);
wchar_t* wstr_trim(wchar_t* str, wchar_t ch);
void init_hold(void);

#endif
