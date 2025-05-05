%{
#include "parser.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
%}

DIGITO  [0-9]
LETRA   [a-zA-Z]
ID      {LETRA}({LETRA}|{DIGITO})*
NUM     {DIGITO}+(\.{DIGITO}+)?([eE][+-]?{DIGITO}+)?
ESPACO  [ \t\n]+

%%
"main"  { return TK_MAIN; }
"int"   { return TK_TIPO_INT; }
"float" { return TK_TIPO_FLOAT; }
"char"  { return TK_TIPO_CHAR; }
"bool"  { return TK_TIPO_BOOL; }
"fim"   { return TK_FIM; }
"="     { return TK_ATRIBUICAO; }
"+"     { return TK_SOMA; }
"-"     { return TK_SUBTRACAO; }
"*"     { return TK_MULTIPLICACAO; }
"/"     { return TK_DIVISAO; }
"<"     { return TK_MENOR; }
">"     { return TK_MAIOR; }
"<="    { return TK_MENOR_IGUAL; }
">="    { return TK_MAIOR_IGUAL; }
"=="    { return TK_IGUALDADE; }
"!="    { return TK_DIFERENTE; }
"&&"    { return TK_E_LOGICO; }
"||"    { return TK_OU_LOGICO; }
"!"     { return TK_NEGACAO; }

{ID}    {
    yylval.label = strdup(yytext);
    return TK_ID;
}

{NUM}   { 
    yylval.label = strdup(yytext);
    return TK_NUM;
}

{ESPACO} { /* Ignorar espaços */ }

. { 
    fprintf(stderr, "Caractere inválido: %s\n", yytext);
    return TK_ERROR;
}

%%

int yywrap() {
    return 1;
}
