%{
#include <stdio.h>
#include <stdlib.h>

int tempCount = 0;
int genTemp() {
    return ++tempCount;
}

int yylex(void);
int yyerror(const char *s);
%}

%union {
    int ival;
    struct {
        int temp;
    } expr;
}

%token <ival> NUM
%type <expr> Expressao Termo

%%

Programa:
    Expressao {
        printf("\nCódigo intermediário finalizado.\n");
    }
;

Expressao:
    Expressao '+' Termo {
        int temp = genTemp();
        printf("int T%d;\n", temp);
        printf("T%d = T%d + T%d;\n", temp, $1.temp, $3.temp);
        $$ = $1;
        $$.temp = temp;
    }
  | Termo {
        $$ = $1;
    }
;

Termo:
    NUM {
        int temp = genTemp();
        printf("int T%d;\n", temp);
        printf("T%d = %d;\n", temp, $1);
        $$.temp = temp;
    }
;

%%

int main() {
     while (1) {
        printf("Digite uma expressão: ");
        yyparse();
        yyrestart(stdin);  // reinicia o scanner
    }
}

int yyerror(const char *msg) {
    printf("Erro: %s\n", msg);
    return 0;
}
