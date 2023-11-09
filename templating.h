#ifndef TEMPLATING_H_
#define TEMPLATING_H_

typedef struct TemplateSymTable symtbl_t;

void init_transpile_state(void);
void reset_transpile_state(void);
void write_variable(char* type, char* name, char* init);
void write_function(char* name, char* args, char* body);
void write_if(char* cond, char* body);
void write_elseif(char* cond, char* body);
void write_else(char* body);
void write_forloop(char* start, char* cond, char* step, char* body);
void write_whileloop(char* cond, char* body);
void write_goto(char* label, char* after);
void tmpl_add_symbol(uint8_t* name, void* value, enum Symtype type);
void tmpl_get_symbol(uint8_t* name, void** value, enum Symtype* type);
void tmpl_delete_symbol(uint8_t* name);

#endif
