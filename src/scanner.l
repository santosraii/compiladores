%{
#include "parser.tab.h"
#include <stdio.h>

%}

SPACE [ \t]
DIGIT [0-9]
LETTER [A-Za-z]
UNDERSCORE _

NUMBER ({DIGIT})+

REAL [-]?(((({DIGIT}+)|({DIGIT}*\.{DIGIT}+))([eE][-+]?{DIGIT}+)?))
DECIMAL_INTEGER [-]?{NUMBER}

CHAR \'({LETTER}|{DIGIT})\'
STRING \"(\\.|[^"\\])*\"
ID ({LETTER}|{UNDERSCORE})({LETTER}|{DIGIT}|{UNDERSCORE})*

BOOLEAN "true"|"false"
TYPES "int"|"float"|"bool"|"char"|"string"

%%

{SPACE}+    { /* ignore whitespace */ }
"\n" { /* ignore newlines */ }

";" { return TK_SEMICOLON; }
":" { return TK_COLON; }

"(" { return TK_OPEN_PARENTHESIS; }
")" { return TK_CLOSE_PARENTHESIS; }

"var" { return TK_VAR; }

"do" { return TK_DO; }
"while" { return TK_WHILE; }
"for" { return TK_FOR; }
"continue" { return TK_CONTINUE; }
"break" { return TK_BREAK; }

"if" { return TK_IF; }
"else" { return TK_ELSE; }

"return" { return TK_RETURN; }

"and" { return TK_AND; }
"or" { return TK_OR; }
"not" { return TK_NOT; }

"+" { return TK_PLUS; }
"-" { return TK_MINUS; }
"*" { return TK_MULT; }
"/" { return TK_DIV; }
"%" { return TK_MOD; }
"==" { return TK_EQ; }
"!=" { return TK_NE; }
"=" { return TK_ASSIGN; }

">" { return TK_GT; }
"<" { return TK_LT; }
">=" { return TK_GE; }
"<=" { return TK_LE; }

"." { return TK_DOT; }

{TYPES} { yylval.label = yytext; return TK_TYPE; }

{STRING} { yylval.label = yytext; return TK_STRING; }
{CHAR} { yylval.label = yytext; return TK_CHAR; }
{BOOLEAN} { yylval.label = yytext; return TK_BOOLEAN; }
{DECIMAL_INTEGER} { yylval.label = yytext; return TK_NUM; }
{REAL} { yylval.label = yytext; return TK_REAL; }

{ID} { yylval.label = yytext; return TK_ID; }

. { *yytext; }

%%
