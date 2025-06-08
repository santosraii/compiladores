%{
#include <iostream>
#include <string>
#include <sstream>
#include "../src/compiler.h"

using namespace std;
using namespace compiler;

typedef struct {
    string label;
    string traducao;
    string tipo;
} Atributo;

Compilador compilador = Compilador();

int variableCount = 0;

string generateName() {
    return "t" + to_string(variableCount++);
}

#define YYSTYPE Atributo

int yylex(void);
int yyerror(string msg);
%}

%token TK_SEMICOLON TK_COLON TK_OPEN_PARENTHESIS TK_CLOSE_PARENTHESIS
%token TK_VAR TK_DO TK_WHILE TK_FOR TK_CONTINUE TK_BREAK TK_IF
%token TK_ELSE TK_RETURN TK_AND TK_OR TK_NOT TK_PLUS TK_MINUS TK_MULT
%token TK_DIV TK_MOD TK_EQ TK_NE TK_ASSIGN TK_GT TK_LT TK_GE TK_LE
%token TK_DOT TK_TYPE TK_STRING TK_CHAR TK_NUM TK_REAL TK_BOOLEAN TK_ID

%start START

%right TK_ASSIGN

%left TK_AND
%left TK_OR
%left TK_EQ TK_NE TK_GT TK_LT TK_GE TK_LE

%left TK_PLUS TK_MINUS
%left TK_MULT TK_DIV TK_MOD
%right '.'

%left TK_NOT

%%

START: COMMANDS {
    compilador.compilar($1.traducao);
}

COMMANDS: COMMAND COMMANDS { $$.traducao = $1.traducao + $2.traducao; } 
        | { $$.traducao = ""; }

COMMAND: CRIAR_CONTEXTO COMMANDS ENCERRAR_CONTEXTO { $$.traducao = $2.traducao; }
        | DECLARAR_VARIAVEL TK_SEMICOLON { $$ = $1; }
        | ATRIBUIR_VARIAVEL TK_SEMICOLON { $$ = $1; }

CRIAR_CONTEXTO: '{' { compilador.debug("Criando contexto"); compilador.adicionarContexto(); }

ENCERRAR_CONTEXTO: '}' { compilador.debug("Encerrando contexto"); compilador.removerUltimoContexto(); }

DECLARAR_VARIAVEL: TK_VAR TK_ID TK_ASSIGN EXPRESSAO {
                    compilador.debug("Declarando variável " + $2.label + " com expressão " + $4.traducao);

                    auto var = compilador.getContextoAtual()->buscarVariavel($2.label);

                    if (var != NULL) {
                        yyerror("A variável \"" + $2.label + "\" já foi declarada nesse contexto");
                    }

                    string nomeFicticio = generateName();

                    compilador.adicionarVariavel($2.label, nomeFicticio, $4.tipo);

                    $$.label = nomeFicticio;
                    $$.tipo = $4.tipo;
                    $$.traducao = $4.traducao;

                    if ($4.tipo == TIPO_STRING) { // ISSO NÃO PODE, TEMOS QUE MUDAR ISSO
                        $$.traducao += $$.label + ".data = " + $4.label + ".data;\n";
                        $$.traducao += $$.label + ".length = " + $4.label + ".length;\n";
                    } else {
                        $$.traducao += $$.label + " = " + $4.label + ";\n";
                    }

                }
                |
                TK_VAR TK_ID TK_COLON TK_TYPE TK_ASSIGN EXPRESSAO {
                    compilador.debug("Declarando variável " + $2.label + " com expressão " + $5.traducao);

                    if ($4.label != $6.tipo) {
                        yyerror("O tipo da variável \"" + $2.label + "\" não corresponde ao tipo declarado");
                    }

                    auto var = compilador.getContextoAtual()->buscarVariavel($2.label);

                    if (var != NULL) {
                        yyerror("A variável \"" + $2.label + "\" já foi declarada nesse contexto");
                    }

                    string nomeFicticio = generateName();

                    compilador.adicionarVariavel($2.label, nomeFicticio, $6.tipo);

                    $$.label = nomeFicticio;
                    $$.tipo = $6.tipo;
                    $$.traducao = $6.traducao;

                    if ($6.tipo == TIPO_STRING) { // ISSO NÃO PODE, TEMOS QUE MUDAR ISSO
                        $$.traducao += $$.label + ".data = " + $6.label + ".data;\n";
                        $$.traducao += $$.label + ".length = " + $6.label + ".length;\n";
                    } else {
                        $$.traducao += $$.label + " = " + $6.label + ";\n";
                    }
                }

ATRIBUIR_VARIAVEL: TK_ID TK_ASSIGN EXPRESSAO {
                    compilador.debug("Atribuindo variável " + $1.label + " com expressão " + $3.traducao);

                    auto var = compilador.buscarVariavel($1.label);

                    if (var == NULL) {
                        yyerror("Não foi possível encontrar a variável \"" + $1.label + "\"");
                    }

                    if (var->tipo != $3.tipo) {
                        yyerror("O tipo da variável \"" + $1.label + "\" (" + var->tipo + ") não corresponde ao tipo da expressão (" + $3.tipo + ")");
                    }

                    $$.traducao = $3.traducao;

                    if (var->tipo == TIPO_STRING) { // ISSO NÃO PODE, TEMOS QUE MUDAR ISSO
                        $$.traducao += var->nomeFicticio + ".data = " + $3.label + ".data;\n";
                        $$.traducao += var->nomeFicticio + ".length = " + $3.label + ".length;\n";
                    } else {
                        $$.traducao += var->nomeFicticio + " = " + $3.label + ";\n";
                    }

                    $$.label = $1.label;
                    $$.tipo = $3.tipo;
                }

// EXPRESSAO:  CONVERSAO_EXPLICITA { $$ = $1; }
EXPRESSAO: OPERADORES_ARITMETICOS { $$ = $1; }
            | OPERADORES_LOGICOS { $$ = $1; }
            | OPERADORES_RELACIONAIS { $$ = $1; }
            | LITERAIS { $$.traducao = $1.traducao; }
            | PRIMARIA { $$.traducao = $1.traducao; }

// CONVERSAO_EXPLICITA: TK_OPEN_PARENTHESIS TK_TYPE TK_CLOSE_PARENTHESIS EXPRESSAO {
//                         compilador.debug("Convertendo expressão " + $4.traducao + " para tipo " + $2.label);
//                         $$.traducao = $4.traducao;
//                         $$.tipo = $2.label;
//                     }

OPERADORES_ARITMETICOS: EXPRESSAO TK_PLUS EXPRESSAO {
                        compilador.debug("Somando expressão " + $1.label + " (" + $1.tipo + ") com expressão " + $3.label + " (" + $3.tipo + ")");

                        if (!compilador.isArithmetic($1.tipo) || !compilador.isArithmetic($3.tipo)) {
                            yyerror("Operadores aritméticos só podem ser aplicados a tipos numéricos");
                        }
                        
                        $$.traducao = $1.traducao + $3.traducao;

                        string tipoFinal = $1.tipo == $3.tipo ? $1.tipo : TIPO_FLOAT;

                        string nomeFicticio = generateName();
                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, tipoFinal);

                        string temp1 = $1.label;
                        string temp2 = $3.label;

                        if ($1.tipo != tipoFinal) {
                            string temp1Name = generateName();
                            compilador.debug("Convertendo implícita expressão " + $1.label + " para tipo " + tipoFinal);
                            compilador.adicionarVariavel(temp1Name, temp1Name, tipoFinal);
                            $$.traducao += temp1Name + " = (float)" + $1.label + ";\n";
                            temp1 = temp1Name;
                        }

                        if ($3.tipo != tipoFinal) {
                            string temp2Name = generateName();
                            compilador.debug("Convertendo implícita expressão " + $3.label + " para tipo " + tipoFinal);
                            compilador.adicionarVariavel(temp2Name, temp2Name, tipoFinal);
                            $$.traducao += temp2Name + " = (float)" + $3.label + ";\n";
                            temp2 = temp2Name;
                        }

                        $$.traducao += nomeFicticio + " = " + temp1 + " + " + temp2 + ";\n";
                        $$.tipo = tipoFinal;
                        $$.label = nomeFicticio;
                    }
                    | EXPRESSAO TK_MINUS EXPRESSAO {
                        compilador.debug("Subtraindo expressão " + $1.label + " (" + $1.tipo + ") com expressão " + $3.label + " (" + $3.tipo + ")");

                        if (!compilador.isArithmetic($1.tipo) || !compilador.isArithmetic($3.tipo)) {
                            yyerror("Operadores aritméticos só podem ser aplicados a tipos numéricos");
                        }
                        
                        $$.traducao = $1.traducao + $3.traducao;

                        string tipoFinal = $1.tipo == $3.tipo ? $1.tipo : TIPO_FLOAT;

                        string nomeFicticio = generateName();
                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, tipoFinal);

                        string temp1 = $1.label;
                        string temp2 = $3.label;

                        if ($1.tipo != tipoFinal) {
                            string temp1Name = generateName();
                            compilador.debug("Convertendo implícita expressão " + $1.label + " para tipo " + tipoFinal);
                            compilador.adicionarVariavel(temp1Name, temp1Name, tipoFinal);
                            $$.traducao += temp1Name + " = (float)" + $1.label + ";\n";
                            temp1 = temp1Name;
                        }

                        if ($3.tipo != tipoFinal) {
                            string temp2Name = generateName();
                            compilador.debug("Convertendo implícita expressão " + $3.label + " para tipo " + tipoFinal);
                            compilador.adicionarVariavel(temp2Name, temp2Name, tipoFinal);
                            $$.traducao += temp2Name + " = (float)" + $3.label + ";\n";
                            temp2 = temp2Name;
                        }

                        $$.traducao += nomeFicticio + " = " + temp1 + " - " + temp2 + ";\n";
                        $$.tipo = tipoFinal;
                        $$.label = nomeFicticio;
                    }
                    | EXPRESSAO TK_MULT EXPRESSAO {
                        compilador.debug("Multiplicando expressão " + $1.label + " (" + $1.tipo + ") com expressão " + $3.label + " (" + $3.tipo + ")");

                        if (!compilador.isArithmetic($1.tipo) || !compilador.isArithmetic($3.tipo)) {
                            yyerror("Operadores aritméticos só podem ser aplicados a tipos numéricos");
                        }
                        
                        $$.traducao = $1.traducao + $3.traducao;

                        string tipoFinal = $1.tipo == $3.tipo ? $1.tipo : TIPO_FLOAT;

                        string nomeFicticio = generateName();
                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, tipoFinal);

                        string temp1 = $1.label;
                        string temp2 = $3.label;

                        if ($1.tipo != tipoFinal) {
                            string temp1Name = generateName();
                            compilador.debug("Convertendo implícita expressão " + $1.label + " para tipo " + tipoFinal);
                            compilador.adicionarVariavel(temp1Name, temp1Name, tipoFinal);
                            $$.traducao += temp1Name + " = (float)" + $1.label + ";\n";
                            temp1 = temp1Name;
                        }

                        if ($3.tipo != tipoFinal) {
                            string temp2Name = generateName();
                            compilador.debug("Convertendo implícita expressão " + $3.label + " para tipo " + tipoFinal);
                            compilador.adicionarVariavel(temp2Name, temp2Name, tipoFinal);
                            $$.traducao += temp2Name + " = (float)" + $3.label + ";\n";
                            temp2 = temp2Name;
                        }

                        $$.traducao += nomeFicticio + " = " + temp1 + " * " + temp2 + ";\n";
                        $$.tipo = tipoFinal;
                        $$.label = nomeFicticio;
                    }
                    | EXPRESSAO TK_DIV EXPRESSAO {
                        compilador.debug("Dividindo expressão " + $1.label + " (" + $1.tipo + ") com expressão " + $3.label + " (" + $3.tipo + ")");

                        if (!compilador.isArithmetic($1.tipo) || !compilador.isArithmetic($3.tipo)) {
                            yyerror("Operadores aritméticos só podem ser aplicados a tipos numéricos");
                        }
                        
                        $$.traducao = $1.traducao + $3.traducao;

                        string tipoFinal = TIPO_FLOAT;

                        string nomeFicticio = generateName();
                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, tipoFinal);

                        string temp1 = $1.label;
                        string temp2 = $3.label;

                        if ($1.tipo != tipoFinal) {
                            string temp1Name = generateName();
                            compilador.debug("Convertendo implícita expressão " + $1.label + " para tipo " + tipoFinal);
                            compilador.adicionarVariavel(temp1Name, temp1Name, tipoFinal);
                            $$.traducao += temp1Name + " = (float)" + $1.label + ";\n";
                            temp1 = temp1Name;
                        }

                        if ($3.tipo != tipoFinal) {
                            string temp2Name = generateName();
                            compilador.debug("Convertendo implícita expressão " + $3.label + " para tipo " + tipoFinal);
                            compilador.adicionarVariavel(temp2Name, temp2Name, tipoFinal);
                            $$.traducao += temp2Name + " = (float)" + $3.label + ";\n";
                            temp2 = temp2Name;
                        }

                        $$.traducao += nomeFicticio + " = " + temp1 + " / " + temp2 + ";\n";
                        $$.tipo = tipoFinal;
                        $$.label = nomeFicticio;
                    }
                    | EXPRESSAO TK_MOD EXPRESSAO {
                        compilador.debug("Calculando resto da divisão entre expressão " + $1.label + " (" + $1.tipo + ") e expressão " + $3.label + " (" + $3.tipo + ")");

                        if ($1.tipo != TIPO_INT || $3.tipo != TIPO_INT) {
                            yyerror("Operador de módulo só pode ser aplicado a tipos inteiros");
                        }

                        string nomeFicticio = generateName();

                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, $1.tipo);

                        $$.traducao = $1.traducao + $3.traducao;
                        $$.traducao += nomeFicticio + " = " + $1.label + " % " + $3.label + ";\n";
                        $$.tipo = $1.tipo;
                        $$.label = nomeFicticio;
                    }

OPERADORES_RELACIONAIS: EXPRESSAO TK_EQ EXPRESSAO {
                        compilador.debug("Comparando expressão " + $1.label + " (" + $1.tipo + ") com expressão " + $3.label + " (" + $3.tipo + ")");
                        
                        if ($1.tipo != $3.tipo) {
                            yyerror("Operadores relacionais só podem ser aplicados a tipos iguais");
                        }

                        string nomeFicticio = generateName();

                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, TIPO_BOOLEAN);

                        $$.traducao = $1.traducao + $3.traducao;
                        $$.traducao += nomeFicticio + " = " + $1.label + " == " + $3.label + ";\n";
                        $$.tipo = TIPO_BOOLEAN;
                        $$.label = nomeFicticio;
                    }
                    | EXPRESSAO TK_NE EXPRESSAO {
                        compilador.debug("Comparando expressão " + $1.label + " (" + $1.tipo + ") com expressão " + $3.label + " (" + $3.tipo + ")");

                        if ($1.tipo != $3.tipo) {
                            yyerror("Operadores relacionais só podem ser aplicados a tipos iguais");
                        }

                        string nomeFicticio = generateName();
                        
                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, TIPO_BOOLEAN);

                        $$.traducao = $1.traducao + $3.traducao;
                        $$.traducao += nomeFicticio + " = " + $1.label + " != " + $3.label + ";\n";
                        $$.tipo = TIPO_BOOLEAN;
                        $$.label = nomeFicticio;
                    }
                    | EXPRESSAO TK_GT EXPRESSAO {
                        compilador.debug("Comparando expressão " + $1.label + " (" + $1.tipo + ") com expressão " + $3.label + " (" + $3.tipo + ")");

                        if (!compilador.isArithmetic($1.tipo) || !compilador.isArithmetic($3.tipo)) {
                            yyerror("Esse operador relacional só pode ser aplicado a tipos numéricos");
                        }

                        string nomeFicticio = generateName();

                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, TIPO_BOOLEAN);

                        $$.traducao = $1.traducao + $3.traducao;
                        $$.traducao += nomeFicticio + " = " + $1.label + " > " + $3.label + ";\n";
                        $$.tipo = TIPO_BOOLEAN;
                        $$.label = nomeFicticio;
                    }
                    | EXPRESSAO TK_LT EXPRESSAO {
                        compilador.debug("Comparando expressão " + $1.label + " (" + $1.tipo + ") com expressão " + $3.label + " (" + $3.tipo + ")");

                        if (!compilador.isArithmetic($1.tipo) || !compilador.isArithmetic($3.tipo)) {
                            yyerror("Esse operador relacional só pode ser aplicado a tipos numéricos");
                        }

                        string nomeFicticio = generateName();

                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, TIPO_BOOLEAN);

                        $$.traducao = $1.traducao + $3.traducao;
                        $$.traducao += nomeFicticio + " = " + $1.label + " < " + $3.label + ";\n";
                        $$.tipo = TIPO_BOOLEAN;
                        $$.label = nomeFicticio;
                    }
                    | EXPRESSAO TK_GE EXPRESSAO {
                        compilador.debug("Comparando expressão " + $1.label + " (" + $1.tipo + ") com expressão " + $3.label + " (" + $3.tipo + ")");

                        if (!compilador.isArithmetic($1.tipo) || !compilador.isArithmetic($3.tipo)) {
                            yyerror("Esse operador relacional só pode ser aplicado a tipos numéricos");
                        }

                        string nomeFicticio = generateName();

                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, TIPO_BOOLEAN);

                        $$.traducao = $1.traducao + $3.traducao;
                        $$.traducao += nomeFicticio + " = " + $1.label + " >= " + $3.label + ";\n";
                        $$.tipo = TIPO_BOOLEAN;
                        $$.label = nomeFicticio;
                    }
                    | EXPRESSAO TK_LE EXPRESSAO {
                        compilador.debug("Comparando expressão " + $1.label + " (" + $1.tipo + ") com expressão " + $3.label + " (" + $3.tipo + ")");

                        if (!compilador.isArithmetic($1.tipo) || !compilador.isArithmetic($3.tipo)) {
                            yyerror("Esse operador relacional só pode ser aplicado a tipos numéricos");
                        }

                        string nomeFicticio = generateName();

                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, TIPO_BOOLEAN);

                        $$.traducao = $1.traducao + $3.traducao;
                        $$.traducao += nomeFicticio + " = " + $1.label + " <= " + $3.label + ";\n";
                        $$.tipo = TIPO_BOOLEAN;
                        $$.label = nomeFicticio;
                    }

OPERADORES_LOGICOS: EXPRESSAO TK_AND EXPRESSAO {
                        compilador.debug("Aplicando operador lógico AND entre expressão " + $1.label + " (" + $1.tipo + ") e expressão " + $3.label + " (" + $3.tipo + ")");

                        if ($1.tipo != TIPO_BOOLEAN || $3.tipo != TIPO_BOOLEAN) {
                            yyerror("Operadores lógicos só podem ser aplicados a tipos booleanos");
                        }

                        string nomeFicticio = generateName();

                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, TIPO_BOOLEAN);
                        
                        $$.traducao = $1.traducao + $3.traducao;
                        $$.traducao += nomeFicticio + " = " + $1.label + " && " + $3.label + ";\n";
                        $$.tipo = TIPO_BOOLEAN;
                        $$.label = nomeFicticio;
                    }
                    | EXPRESSAO TK_OR EXPRESSAO {
                        compilador.debug("Aplicando operador lógico OR entre expressão " + $1.label + " (" + $1.tipo + ") e expressão " + $3.label + " (" + $3.tipo + ")");

                        if ($1.tipo != TIPO_BOOLEAN || $3.tipo != TIPO_BOOLEAN) {
                            yyerror("Operadores lógicos só podem ser aplicados a tipos booleanos");
                        }

                        string nomeFicticio = generateName();

                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, TIPO_BOOLEAN);

                        $$.traducao = $1.traducao + $3.traducao;
                        $$.traducao += nomeFicticio + " = " + $1.label + " || " + $3.label + ";\n";
                        $$.tipo = TIPO_BOOLEAN;
                        $$.label = nomeFicticio;
                    }
                    | TK_NOT EXPRESSAO {
                        compilador.debug("Aplicando operador lógico NOT à expressão " + $2.label + " (" + $2.tipo + ")");

                        if ($2.tipo != TIPO_BOOLEAN) {
                            yyerror("Operador lógico NOT só pode ser aplicado a tipos booleanos");
                        }

                        string nomeFicticio = generateName();
                        
                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, TIPO_BOOLEAN);

                        $$.traducao = $2.traducao;
                        $$.traducao += nomeFicticio + " = !" + $2.label + ";\n";
                        $$.tipo = TIPO_BOOLEAN;
                        $$.label = nomeFicticio;
                    }

LITERAIS: TK_NUM { 
            compilador.debug("Gerando literal numérico " + $1.label);
            $$.label = generateName();
            $$.tipo = TIPO_INT;
            $$.traducao = $$.label + " = " + $1.label + ";\n";
            compilador.adicionarVariavel($$.label, $$.label, $$.tipo);
        }
        | TK_REAL { 
            compilador.debug("Gerando literal real " + $1.label);
            $$.label = generateName();
            $$.tipo = TIPO_FLOAT;
            $$.traducao = $$.label + " = " + $1.label + ";\n";
            compilador.adicionarVariavel($$.label, $$.label, $$.tipo);
        }
        | TK_CHAR {
            compilador.debug("Gerando literal char " + $1.label);
            $$.label = generateName();
            $$.tipo = TIPO_CHAR;
            $$.traducao = $$.label + " = " + $1.label + ";\n";
            compilador.adicionarVariavel($$.label, $$.label, $$.tipo);
        }
        | TK_BOOLEAN {
            compilador.debug("Gerando literal boolean " + $1.label);
            $$.label = generateName();
            $$.tipo = TIPO_BOOLEAN;
            $$.traducao = $$.label + " = " + $1.label + ";\n";
            compilador.adicionarVariavel($$.label, $$.label, $$.tipo);
        }
        | TK_STRING {
            compilador.debug("Gerando literal string " + $1.label);
            $$.label = generateName();
            $$.tipo = TIPO_STRING;

            int size = $1.label.length() - 1;

            $$.traducao = $$.label + ".data = (char*)malloc(" + to_string(size) + " * sizeof(char));\n";

            for (int i = 0; i < size - 1; i++) {
                $$.traducao += $$.label + ".data[" + to_string(i) + "] = '" + $1.label[i + 1] + "';\n";
            }

            $$.traducao += $$.label + ".data[" + to_string(size - 1) + "] = '\\0';\n";

            $$.traducao += $$.label + ".length = " + to_string(size) + ";\n";

            compilador.adicionarVariavel($$.label, $$.label, $$.tipo);
        }

PRIMARIA: TK_ID {
            compilador.debug("Buscando variável " + $1.label);
            auto var = compilador.buscarVariavel($1.label);

            if (var == NULL) {
                yyerror("Não foi possível encontrar a variável \"" + $1.label + "\"");
            }

            $$.label = var->nomeFicticio;
            $$.tipo = var->tipo;
        }

%%
#include "lexico.yy.c"

int yyparse();

int main(int argc, char* argv[])
{
	yyparse();
	return 0;
}

int yyerror(string msg) {
    cout << "Erro: " << msg << endl;
    return 0;
}
