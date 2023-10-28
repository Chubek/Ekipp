#define MAX_TOKEN       8
#define MAX_FMT         MAX_TOKEN * 8
#define External        extern

External    char fmt_delim[MAX_FMT]; 
External    char fmt_comment[MAX_FMT];
External    char fmt_quote[MAX_FMT];
External    char delim_left[MAX_TOKEN];
External    char delim_right[MAX_TOKEN];
External    char argnum_sigil[MAX_TOKEN];
External    char engage_sigil[MAX_TOKEN];
External    char cond_sigil[MAX_TOKEN];
External    char search_sigil[MAX_TOKEN];
External    char aux_sigil[MAX_TOKEN];
External    char keyletter;

char*           str_ascii       = GC_MALLOC(LINE_MAX);
wchar_t*        str_wide        = GC_MALLOC(LINE_MAX * sizeof(wchar_t));
ssize_t          str_len        = 0;
char            keycompare      = 0;

if (feof(yyin)) {
        exit(EXIT_SUCCESS);
}

fscanf(yyin, &fmt_comment[0], NULL);

if ((keycompare = fgetc(yyin)) == keyletter && !isblank(keycompare))
        return KEYLETTER;

ungetc(keycompare, yyin);

if ((str_len = fwscanf(yyin, (wchar_t*)&fmt_delim[0], &str_wide)) > 0) {
        yylval.wval = gc_wcsdup(str_wide);
        yylval.lenv = str_len;
        free(str_wide);
        return DELIMITED;
}

if ((str_len = fwscanf(yyin, (wchar_t*)&fmt_quote[0], &str_wide)) > 0) {
        yylval.wval = gc_wcsdup(str_wide);
        yylval.lenv = str_len;
        free(str_wide);
        return WQUOTE;
}

if ((str_len = fscanf(yyin, &fmt_quote[0], &str_ascii)) > 0) {
        yylval.sval = gc_strdup(str_ascii);
        yylval.lenv = str_len;
        free(str_ascii);
        return SQUOTE;
}

if (str_len < 0)
        exit(EXIT_SUCCESS);

char    token[MAX_TOKEN] = {0};
size_t  token_ptr = 0;

while ((token[token_ptr++] = fgetc(yyin)), token_ptr < MAX_TOKEN - 1) {
        if (isblank(token[token_ptr - 1]))
                break;

        if (!strncmp(&token[0], &argnum_sigil[0], MAX_TOKEN))
                return ARGNUM_SIGIL;
        else if (!strncmp(&token[0], &engage_sigil[0], MAX_TOKEN))
                return ENGAGE_SIGIL;
        else if (!strncmp(&token[0], &cond_sigil[0], MAX_TOKEN))
                return COND_SIGIL;
        else if (!strncmp(&token[0], &search_sigil[0], MAX_TOKEN))
                return SEARCH_SIGIL;
        else if (!strncmp(&token[0], &aux_sigil[0], MAX_TOKEN))
                return AUX_SIGIL;

}

while (--token_ptr) 
        ungetc(token[token_ptr], yyin);



