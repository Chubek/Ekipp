FILES := lex.yy.c y.tab.c y.tab.h ekipp

all: clean lexer parser errcodes ekipp

ekipp: lex.yy.c y.tab.c y.tab.h err \
	errors.gen ekipp.c yylex.i ekipp.h
	cc ekipp.c y.tab.c lex.yy.c -ll

errcodes: 
	perl errgen.pl

parser: lex.yy.c
	yacc -d ekipp.y

lexer:
	lex ekipp.l

.PHONY
clean: $(FILES)
	rm -f $(FILES)
