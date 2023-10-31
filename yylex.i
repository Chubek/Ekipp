#define MAX_TOKEN       8
#define MAX_FMT         MAX_TOKEN * 8

#define IS_DLIM_RIGHT   (!strncmp(&token[0], &delim_right[0], MAX_TOKEN))
#define IS_DLIM_LEFT    (!strncmp(&token[0], &delim_left[0], MAX_TOKEN))
#define IS_COMM_RIGHT   (!strncmp(&token[0], &comment_right[0], MAX_TOKEN))
#define IS_COMM_LEFT    (!strncmp(&token[0], &comment_left[0], MAX_TOKEN))
#define IS_QUOT_RIGHT   (!strncmp(&token[0], &quote_right[0], MAX_TOKEN))
#define IS_QUOT_LEFT    (!strncmp(&token[0], &quote_left[0], MAX_TOKEN))
#define IS_SIGIL_ENG    (!strncmp(&token[0], &engage_sigil[0], MAX_TOKEN))

extern    char quote_left[MAX_TOKEN];
extern    char quote_right[MAX_TOKEN];
extern    char comment_left[MAX_TOKEN];
extern    char comment_right[MAX_TOKEN];
extern    char delim_left[MAX_TOKEN];
extern    char delim_right[MAX_TOKEN];
extern    char engage_sigil[MAX_TOKEN];
extern    char comment_fmt[MAX_FMT];

fscanf(yyin, &comment_fmt[0], NULL);

char*           str_ascii;
wchar_t*        str_wide;
char            token[MAX_TOKEN] = {0};
wchar_t         wchr;
size_t          token_ptr = 0;
size_t          ascii_ptr = 0;
size_t          wide_ptr  = 0;

while ((token[token_ptr++] = fgetc(yyin)), token_ptr < MAX_TOKEN - 1) {
        if (isblank(token[token_ptr - 1]))
                break;
        else if (IS_SIGIL_ENG) {
                BEGIN(ENG);
                return ENGAGE_PREFIX;
        } else if (IS_QUOT_LEFT || IS_DLIM_LEFT) {
                str_wide        = NULL;
                str_ascii       = NULL;
                
                str_wide        = GC_MALLOC(sizeof(wchar_t));
                str_ascii       = GC_MALLOC(sizeof(char));

                while (!(IS_QUOT_RIGHT || IS_DLIM_RIGHT)) {
                        wchr = fgetwc(yyin);
                        if (wchr < INT8_MAX) {
                                str_ascii =
                                        GC_REALLOC(str_ascii, ascii_ptr);

                                str_ascii[ascii_ptr++] = (char)wchr;                                       if (token_ptr == MAX_TOKEN)
                                        token_ptr = 0;
                        }
                        str_wide =
                                GC_REALLOC(str_wide, wide_ptr * sizeof(wchar_t));
                        str_wide[wide_ptr++] = wchr;
                }
                yylval.wval = str_wide;
                yylval.sval = str_ascii;
                if (IS_QUOT_RIGHT)
                        return QUOTED;
                else
                        return DELIMITED;
        }
}

while (--token_ptr) 
        ungetc(token[token_ptr], yyin);



