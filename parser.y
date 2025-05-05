%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define YYSTYPE struct atributos

struct atributos {
    char* label;
    char* traducao;
};

int yylex();
void yyerror(const char *msg);
%}

%token TK_NUM TK_ID TK_MAIN TK_TIPO_INT TK_TIPO_FLOAT TK_TIPO_CHAR TK_TIPO_BOOL TK_FIM TK_ERROR TK_ATRIBUICAO
%token TK_SOMA TK_SUBTRACAO TK_MULTIPLICACAO TK_DIVISAO
%token TK_MENOR TK_MAIOR TK_MENOR_IGUAL TK_MAIOR_IGUAL TK_IGUALDADE TK_DIFERENTE
%token TK_E_LOGICO TK_OU_LOGICO TK_NEGACAO

%left TK_SOMA TK_SUBTRACAO
%left TK_MULTIPLICACAO TK_DIVISAO

%start S

%%

S:
    TK_MAIN expr TK_FIM {
        if ($2.traducao) {
            printf("Resultado final: %s\n", $2.traducao);
        } else {
            printf("Erro: Expressão inválida.\n");
        }
    }
;

expr:
    TK_NUM {
        struct atributos at;
        at.label = strdup($1.label);
        at.traducao = strdup($1.label);
        $$ = at;
    }
    | TK_ID {
        struct atributos at;
        at.label = strdup($1.label);
        at.traducao = strdup($1.label);
        $$ = at;
    }
    | expr TK_SOMA expr {
        struct atributos at;
        at.traducao = malloc(strlen($1.traducao) + strlen($3.traducao) + 4);
        sprintf(at.traducao, "(%s+%s)", $1.traducao, $3.traducao);
        $$ = at;
    }
    | expr TK_SUBTRACAO expr {
        struct atributos at;
        at.traducao = malloc(strlen($1.traducao) + strlen($3.traducao) + 4);
        sprintf(at.traducao, "(%s-%s)", $1.traducao, $3.traducao);
        $$ = at;
    }
    | expr TK_MULTIPLICACAO expr {
        struct atributos at;
        at.traducao = malloc(strlen($1.traducao) + strlen($3.traducao) + 4);
        sprintf(at.traducao, "(%s*%s)", $1.traducao, $3.traducao);
        $$ = at;
    }
    | expr TK_DIVISAO expr {
        struct atributos at;
        at.traducao = malloc(strlen($1.traducao) + strlen($3.traducao) + 4);
        sprintf(at.traducao, "(%s/%s)", $1.traducao, $3.traducao);
        $$ = at;
    }
    | expr TK_ATRIBUICAO expr {
        struct atributos at;
        at.traducao = malloc(strlen($1.traducao) + strlen($3.traducao) + 5);
        sprintf(at.traducao, "%s = %s;", $1.traducao, $3.traducao);
        $$ = at;
    }
;

%%

int main() {
    printf("Digite uma expressão e termine com 'fim':\n");
    yyparse();
    return 0;
}

void yyerror(const char *msg) {
    fprintf(stderr, "Erro: %s\n", msg);
}
