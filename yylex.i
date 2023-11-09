fflush(yyout);
uint8_t tok[TOK_MAX + 1] = {0};
tok[0] = fgetc(yyin);
tok[1] = fgetc(yyin);
uint8_t chr = 0;
int i = 0;
if (yy_start == INITIAL) {
  if (!u8_strncmp(&engage_prefix_token[0], &tok[0], TOK_MAX)) {
    BEGIN(ENG);
    return ENGAGE_PREFIX;
  } else if (!u8_strncmp(&define_prefix_token[0], &tok[0], TOK_MAX)) {
    BEGIN(DEF);
    return DEF_PREFIX;
  } else if (!u8_strncmp(&call_prefix_token[0], &tok[0], TOK_MAX)) {
    BEGIN(CAL);
    return CALL_PREFIX;
  } else if (!u8_strncmp(&call_suffix_token[0], &tok[0], TOK_MAX)) {
    BEGIN(INITIAL);
    return CALL_SUFFIX;
  } else if (!u8_strncmp(&quote_left_token[0], &tok[0], TOK_MAX)) {
    yylval.sval = NULL;
    goto yyquote;
  } else if (!u8_strncmp(&comment_left_token[0], &tok[0], TOK_MAX)) {
    goto yycomment;
  } else if (!u8_strncmp(&delim_left_token[0], &tok[0], TOK_MAX)) {
    yylval.sval = NULL;
    goto yydelim;
  } else
    goto yyungettok;
} else if (false) {
yyquote:
  i = 0;
  while ((tok[0] = fgetc(yyin), tok[1] = fgetc(yyin))) {
    if (!u8_strncmp(&quote_right_token[0], &tok[0], TOK_MAX))
      return QUOTED;

    i += 2;
    yylval.sval = GC_REALLOC(yylval.sval, i);
    yylval.sval[i - 1] = tok[1];
    yylval.sval[i - 2] = tok[0];
  }
} else if (false) {
yydelim:
  i = 0;
  while ((tok[0] = fgetc(yyin), tok[1] = fgetc(yyin))) {
    if (!u8_strncmp(&delim_right_token[0], &tok[0], TOK_MAX))
      return DELIMITED;

    i += 2;
    yylval.sval = GC_REALLOC(yylval.sval, i);
    yylval.sval[i - 1] = tok[1];
    yylval.sval[i - 2] = tok[0];
  }
} else if (false) {
yycomment:
  i = 0;
  while ((tok[0] = fgetc(yyin), tok[1] = fgetc(yyin))) {
    if (!u8_strncmp(&comment_right_token[0], &tok[0], TOK_MAX)) {
      BEGIN(INITIAL);
      goto endappend;
    }
  }
} else if (false) {
yyungettok:
  ungetc(tok[0], yyin);
  ungetc(tok[1], yyin);
}

endappend:
