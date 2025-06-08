all:
	mkdir -p out
	lex -o out/lexico.yy.c src/scanner.l
	yacc -d src/parser.y -o out/parser.tab.c -Wcounterexamples -v
	g++ -o out/compiler.exe out/parser.tab.c -ll
	./out/compiler.exe --s < examples/$(FILE).wsl

run:
	mkdir -p out
	lex -o out/lexico.yy.c src/scanner.l
	yacc -d src/parser.y -o out/parser.tab.c -Wcounterexamples -v
	g++ -o out/compiler.exe out/parser.tab.c -ll
	./out/compiler.exe --t < examples/$(FILE).wsl > out/$(FILE).wsl.cpp
	g++ -o out/$(FILE).wsl.exe out/$(FILE).wsl.cpp 
	./out/$(FILE).wsl.exe

compile:
	mkdir -p out
	lex -o out/lexico.yy.c src/scanner.l
	yacc -d src/parser.y -o out/parser.tab.c -Wcounterexamples -v
	g++ -o ./out/compiler.exe ./out/parser.tab.c -ll

scanner:
	mkdir -p out
	lex -o out/lexico.yy.c src/scanner.l
	gcc -o out/scanner.out out/lexico.yy.c -lfl
	./out/scanner.out