all: compilador

compilador: parser.tab.c lex.yy.c
	@gcc -o compilador parser.tab.c lex.yy.c -lfl

parser.tab.c parser.tab.h: parser.y
	@bison -d parser.y

lex.yy.c: scanner.l
	@flex scanner.l

clean:
	@rm -f compilador parser.tab.c parser.tab.h lex.yy.c
