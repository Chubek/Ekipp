#ifndef EKIPP_H_
#define EKIPP_H_

#include <wchar.h>
#include <sys/types.h>

#ifndef Inline
#define Inline static inline
#endif

typedef struct LinkedList 	node_t;
typedef struct Defstack	  	stack_t;

Inline void 	insert_symbol(wchar_t* name, wchar_t* value);
Inline wchar_t* get_symbol(wchar_t* name);
Inline void 	free_node(node_t* node);
Inline void 	remove_symbol(wchar_t* name);
Inline void 	dump_symtable(void);
Inline void 	push_stack(wchar_t* name, wchar_t* value);
Inline wchar_t*	get_stack_value(wchar_t* name);
Inline wchar_t* get_stack_pop(void);
Inline void 	dump_stack(void);
Inline void 	set_divert(int n);
Inline void 	unset_divert(int n);
Inline void 	free_set_diverts(void);
Inline void 	switch_output(FILE* stream);
Inline void 	unswitch_output(void);
Inline void 	ifelse_regmatch(void);
Inline void 	search_file(FILE* stream);
Inline void 	open_search_close(char* path);
Inline void 	yyin_search(void);
Inline void 	ifelse_execmatch(void);
Inline void 	init_delim_stream(void);
Inline void 	exec_delim_command(void);
Inline void 	zero_registry(void);
Inline void 	register_token(char* token);
Inline void 	set_token(char* token, char* value);
Inline bool 	token_is(char* token, char* inquiry);
Inline void 	invoke_addarg(wchar_t* arg);
Inline void 	invoke_getarg(size_t n);
Inline void 	invoke_printargs(wchar_t* delim);
Inline void 	invoke_dumpargs(void);
Inline void 	invoke_macro(wchar_t *id);
Inline void 	foreach_macro(wchar_t* macro, char* kwd);
Inline void 	print_formatted(wchar_t* fmt);
Inline void 	set_aux(wchar_t** aux, wchar_t* value);
Inline void 	free_aux(wchar_t* aux);
Inline void 	translit(int action);
Inline void 	offset(void);
Inline void 	list_dir(void);
Inline void 	cat_file(void);
Inline void 	include_file(void);
Inline void 	format_time(void);

#endif
