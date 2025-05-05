%{
#include "parser.tab.h"
#include <stdio.h>

%}

%%
[0-9]+      { yylval.ival = atoi(yytext); return NUM; }
[\n\t ]+    { /* ignorar espaços e quebras de linha */ }
"+"         { return '+'; }
.           { printf("Caractere inválido: %s\n", yytext); }
%%

int yywrap() {
    return 1;
}
