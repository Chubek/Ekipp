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


char*           str_ascii;
wchar_t*        str_wide;
size_t          str_len;
char            keyletter;
char            keycompare;

fscanf(yyin, &fmt_comment[0], NULL);

if ((keycompare = fgetc(yyin)) == keyletter && !isblank(keycompare))
        return KEYLETTER;

ungetc(keycompare, yyin);

if ((str_len = fwscanf(yyin, (wchar_t*)&fmt_delim[0], str_wide)) > 0) {
        yylval.wval = wcsndup(str_wide, str_len);
        yylval.lenv = str_len;
        free(str_wide);
        return DELIMITED;
}

if ((str_len = fwscanf(yyin, (wchar_t*)&fmt_quote[0], str_wide)) > 0) {
        yylval.wval = wcsdup(str_wide, str_len);
        yylval.lenv = str_len;
        free(str_wide);
        return WQUOTE;
}

if ((str_len = fscanf(yyin, &fmt_quote[0], str_ascii)) > 0) {
        yylval.sval = strndup(str_wide, str_len);
        yylval.lenv = str_len;
        free(str_ascii);
        return SQUOTE;
}

char    token[MAX_TOKEN] = {0};
size_t  token_ptr = 0;

while ((token[token_ptr++] = fgetc(yyin)), token_ptr < MAX_TOKEN - 1) {
        if (isblank(token[token_ptr - 1]))
                break;

        if (token_is(&token[0], &argnum_sigil[0], token_ptr)
                return ARGNUM_SIGIL;
        else if (token_is(&token[0], &engage_sigil[0], token_ptr)
                return ENGAGE_SIGIL;
        else if (token_is(&token[0], &cond_sigil[0], token_ptr)
                return COND_SIGIL;
        else if (token_is(&token[0], &search_sigil[0], token_ptr)
                return SEARCH_SIGIL;
        else if (token_is(&token[0], &aux_sigil[0], token_ptr)
                return AUX_SIGIL;

}

while (--token_ptr) 
        ungetc(token[token_ptr], yyin);



