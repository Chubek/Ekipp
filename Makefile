FILES := lex.yy.c yy.tab.c yy.tab.h ekipp



ekipp: errors.gen
	cc ekipp.c startup.c yy.tab.c lex.yy.c -ll -lm -lreadline -o ekipp
 
errors.gen: yy.tab.h
	perl errgen.pl

yy.tab.c: yy.tab.h
	yacc -b yy ekipp.grm.y

yy.tab.h: lex.yy.c 
	yacc -b yy -d ekipp.grm.y

lex.yy.c: clean
	lex ekipp.grm.l

.PHONY : clean
clean: $(FILES)
	rm -f $(FILES)
