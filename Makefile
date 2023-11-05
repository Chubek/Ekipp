FILES := lex.yy.c yy.tab.c yy.tab.h ekipp yybodyeval.c



ekipp: errors.gen
	gcc $(DEBUG) ekipp.c startup.c yy.tab.c lex.yy.c yybodyeval.c -lgc -ll -lm -lreadline -o ekipp
 
errors.gen: yybodyeval.c
	perl errgen.pl

yybodyeval.c: yy.tab.c
	leg -o yybodyeval.c body.grm.leg

yy.tab.c: yy.tab.h
	yacc --debug -b yy ekipp.grm.y

yy.tab.h: lex.yy.c 
	yacc --debug -b yy -d ekipp.grm.y

lex.yy.c: clean
	lex ekipp.grm.l

.PHONY : clean
clean: 
	rm -f $(FILES)
