FILES := lex.yy.c yy.tab.c yy.tab.h ekipp body.tab.c body.tab.h



ekipp: errors.gen
	gcc $(DEBUG) ekipp.c startup.c yy.tab.c lex.yy.c body.tab.c -lgc -ll -lm -lreadline -lunistring -o ekipp
 
errors.gen: body.tab.c
	perl errgen.pl

body.tab.c: body.tab.h
	yacc --debug -b body body.grm.y

body.tab.h: yy.tab.c
	yacc --debug -b body -d body.grm.y

yy.tab.c: yy.tab.h
	yacc --debug -b yy ekipp.grm.y

yy.tab.h: lex.yy.c 
	yacc --debug -b yy -d ekipp.grm.y

lex.yy.c: clean
	lex ekipp.grm.l

.PHONY : clean
clean: 
	rm -f $(FILES)
