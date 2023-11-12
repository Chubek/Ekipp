BUILD_DIR := build
LP_DIR	  := lp
SRC_DIR	  := src
VM_DIR	  := vm
VM_GEN	  := machine-disasm.i  machine-peephole.i  machine-gen.i machine-vm.i
FILES	  := $(VM_GEN) errors.gen yy.tab.c yy.tab.h lex.yy.c body.tab.c body.tab.h ekipp


VM_SRC 	  := $(VM_DIR)/profile.c $(VM_DIR)/peephole.c $(VM_DIR)/disasm.c $(VM_DIR)/vmsupport.c

EKIPP_SRC  := $(SRC_DR)/ekipp.c $(SRC_DIR)/startup.c

LP_SRC     := yy.tab.c lex.yy.c body.tab.c

DEP_LIBS   := -ll -lm -lreadline -lunistring

ekipp: mkall
	cc $(DEBUG) -I. -I$(VM_DIR) -I$(SRC_DIR) $(VM_SRC) $(EKIPP_SRC) $(LP_SRC) $(DEP_LIBS) -o ekipp

.PHONY : dist
dist:
	cc $(DEBUG) $(DEBUG) -I. -I$(VM_DIR) -I$(SRC_DIR) $(VM_SRC) $(EKIPP_SRC) $(LP_SRC) $(DEP_LIBS) -o ekipp

.PHONY : install
install: ekipp.1
	sudo cp ekipp /usr/local/bin/ekipp
	sudo cp ekipp.1 /usr/local/share/man/man1/ekipp.1
	sudo mkdir -p /usr/local/share/doc/ekipp
	sudo cp ekipp.1.html /usr/local/share/doc/ekipp
	sudo cp -r EXAMPLES /usr/local/share/doc/ekipp
	sudo mandb

.PHONY : mkall
mkall: $(VM_GEN)

$(VM_GEN): errors.gen
	vmgen $(VM_DIR)/machine.vmg

errors.gen: body.tab.c
	perl $(SRC_DIR)/errgen.pl

body.tab.c: body.tab.h
	yacc --output=body.tab.c $(LP_DIR)/body.grm.y

body.tab.h: re2c.gen.c
	yacc --output=body.tab.h -d $(LP_DIR)/body.grm.y

re2c.gen.c: yy.tab.c
	re2c -output=re2c.gen.c -T $(LP_DIR)/body.grm.re2c

yy.tab.c: yy.tab.h
	yacc --output=yy.tab.c $(LP_DIR)/ekipp.grm.y

yy.tab.h: lex.yy.c 
	yacc --output=yy.tab.h -d $(LP_DIR)/ekipp.grm.y

lex.yy.c: clean
	lex $(LEX_DEBUG) --output=lex.yy.c $(LP_DIR)/ekipp.grm.l

.PHONY : clean
clean: 
	rm -f $(FILES)
