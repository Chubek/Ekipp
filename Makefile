FILES := lex.yy.c yy.tab.c yy.tab.h body.tab.c body.tab.h ekipp.1 ekipp.1.html

ekipp: errors.gen
	gcc $(DEBUG) ekipp.c startup.c yy.tab.c lex.yy.c body.tab.c -lgc -ll -lm -lreadline -lunistring -o ekipp


.PHONY : dist
dist:
	gcc $(DEBUG) ekipp.c startup.c yy.tab.c lex.yy.c body.tab.c -lgc -ll -lm -lreadline -lunistring -o ekipp

install: ekipp.1
	sudo cp ekipp /usr/local/bin/ekipp
	sudo cp ekipp.1 /usr/local/share/man/man1/ekipp.1
	sudo mkdir -p /usr/local/share/doc/ekipp
	sudo cp ekipp.1.html /usr/local/share/doc/ekipp
	sudo cp -r EXAMPLES /usr/local/share/doc/ekipp
	sudo mandb

ekipp.1: 
	ronn --manual "Ekipp Macro Preprocessor" --organization "Chubak Bidpaa" ekipp.1.ronn


errors.gen: body.tab.c
	perl errgen.pl

body.tab.c: body.tab.h
	yacc -b body body.grm.y

body.tab.h: yy.tab.c
	yacc -b body -d body.grm.y

yy.tab.c: yy.tab.h
	yacc -b yy ekipp.grm.y

yy.tab.h: lex.yy.c 
	yacc -b yy -d ekipp.grm.y

lex.yy.c: clean
	lex ekipp.grm.l

.PHONY : clean
clean: 
	rm -f $(FILES) ekipp
