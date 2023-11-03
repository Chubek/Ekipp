FILES := lex.yy.c yy.tab.c yy.tab.h ekipp yydefeval.c yybodyeval.c



ekipp: errors.gen
	gcc $(DEBUG) ekipp.c startup.c yy.tab.c lex.yy.c yydefeval.c yybodyeval.c -lgc -ll -lm -lreadline -o ekipp
 
errors.gen: yybodyeval.c
	perl errgen.pl

yybodyeval.c: yydefeval.c
	leg -o yybodyeval.c ekipp-body.grm.leg

yydefeval.c: yy.tab.c
	leg -o yydefeval.c ekipp-defn.grm.leg

yy.tab.c: yy.tab.h
	yacc --debug -b yy ekipp-builtin.grm.y

yy.tab.h: lex.yy.c 
	yacc --debug -b yy -d ekipp-builtin.grm.y

lex.yy.c: clean
	lex --debug ekipp-builtin.grm.l

.PHONY : clean
clean: $(FILES)
	rm -f $(FILES)
