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

#define YYSTYPE Atributo

int yylex(void);
int yyerror(string msg);
%}

%token TK_SEMICOLON TK_COLON TK_COMMA TK_OPEN_PARENTHESIS TK_CLOSE_PARENTHESIS TK_OPEN_BRACE TK_CLOSE_BRACE
%token TK_VAR TK_DO TK_WHILE TK_FOR TK_SWITCH TK_CASE TK_DEFAULT TK_CONTINUE TK_BREAK TK_IF
%token TK_ELSE TK_RETURN TK_AND TK_OR TK_NOT TK_PLUS TK_MINUS TK_MULT TK_SCANF TK_PRINTF TK_PRINTFLN
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

%nonassoc THEN
%nonassoc TK_ELSE


%%

START: COMMANDS {
    compilador.compilar($1.traducao);
}

COMMANDS: COMMAND COMMANDS {
            compilador.debug("Adicionando comando ao bloco de comandos");
            $$.traducao = $1.traducao + $2.traducao;
        } 
        | { $$.traducao = ""; }

COMMAND: CRIAR_CONTEXTO COMMANDS ENCERRAR_CONTEXTO {
            compilador.debug("Criando novo contexto a partir de um novo bloco de comandos");
            $$.traducao = $2.traducao;
        }
        | DECLARAR_VARIAVEL PONTO_VIRGULA_OPCIONAL { $$ = $1; }
        | ATRIBUIR_VARIAVEL PONTO_VIRGULA_OPCIONAL { $$ = $1; }
        | COMANDOS_CUSTOMIZADOS PONTO_VIRGULA_OPCIONAL { $$ = $1; }
        | CONTROLE_FLUXO { $$ = $1; }

PONTO_VIRGULA_OPCIONAL: TK_SEMICOLON { $$.traducao = ""; }
                        | { $$.traducao = ""; }

CRIAR_CONTEXTO: TK_OPEN_BRACE { compilador.debug("Criando contexto"); compilador.adicionarContexto(); }

ENCERRAR_CONTEXTO: TK_CLOSE_BRACE { compilador.debug("Encerrando contexto"); compilador.removerUltimoContexto(); }

DECLARAR_VARIAVEL: TK_VAR TK_ID TK_ASSIGN EXPRESSAO {
                    compilador.debug("Declarando variável " + $2.label + " do tipo " + $4.tipo + " com valor " + $4.label);

                    auto var = compilador.getContextoAtual()->buscarVariavel($2.label);

                    if (var != NULL) {
                        yyerror("A variável \"" + $2.label + "\" já foi declarada nesse contexto");
                    }

                    string nomeFicticio = generateName();

                    compilador.adicionarVariavel($2.label, nomeFicticio, $4.tipo);

                    $$.label = nomeFicticio;
                    $$.tipo = $4.tipo;
                    $$.traducao = $4.traducao;

                    if ($4.tipo == TIPO_STRING) {
                        $$.traducao += $$.label + ".data = (char*) malloc(sizeof(char) * " + $4.label + ".length);\n";
                        $$.traducao += "strcpy(" + $$.label + ".data, " + $4.label + ".data);\n";
                        $$.traducao += $$.label + ".length = " + $4.label + ".length;\n";
                    } else {
                        $$.traducao += $$.label + " = " + $4.label + ";\n";
                    }

                }
                |
                TK_VAR TK_ID TK_COLON TK_TYPE TK_ASSIGN EXPRESSAO {
                    compilador.debug("Declarando variável " + $2.label + " do tipo " + $4.tipo + " com valor " + $6.label);

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

                    if ($6.tipo == TIPO_STRING) {
                        $$.traducao += $$.label + ".data = (char*) malloc(sizeof(char) * " + $6.label + ".length);\n";
                        $$.traducao += "strcpy(" + $$.label + ".data, " + $6.label + ".data);\n";
                        $$.traducao += $$.label + ".length = " + $6.label + ".length;\n";
                    } else {
                        $$.traducao += $$.label + " = " + $6.label + ";\n";
                    }
                }

ATRIBUIR_VARIAVEL: TK_ID TK_ASSIGN EXPRESSAO {
                    compilador.debug("Atribuindo variável " + $1.label + " do tipo " + $3.tipo + " com valor " + $3.label);

                    auto var = compilador.buscarVariavel($1.label);

                    if (var == NULL) {
                        yyerror("Não foi possível encontrar a variável \"" + $1.label + "\"");
                    }

                    if (var->tipo != $3.tipo) {
                        yyerror("O tipo da variável \"" + $1.label + "\" (" + var->tipo + ") não corresponde ao tipo da expressão (" + $3.tipo + ")");
                    }

                    $$.traducao = $3.traducao;

                    if (var->tipo == TIPO_STRING) {
                        $$.traducao += var->nomeFicticio + ".data = (char*) malloc(sizeof(char) * " + $3.label + ".length);\n";
                        $$.traducao += "strcpy(" + var->nomeFicticio + ".data, " + $3.label + ".data);\n";
                        $$.traducao += var->nomeFicticio + ".length = " + $3.label + ".length;\n";
                    } else {
                        $$.traducao += var->nomeFicticio + " = " + $3.label + ";\n";
                    }

                    $$.label = $1.label;
                    $$.tipo = $3.tipo;
                }

COMANDOS_CUSTOMIZADOS: TK_BREAK {
                        compilador.debug("Comando BREAK");

                        ControleFluxo* controleFluxo = compilador.getUltimoControleFluxo();

                        if (controleFluxo == NULL) {
                            yyerror("O comando BREAK não pode ser usado fora de um loop ou switch");
                        }

                        if (controleFluxo->isSwitch()) {
                            $$.traducao = "goto " + controleFluxo->fimLabel + ";\n";
                        } else {
                            $$.traducao = "goto " + controleFluxo->fimLabel + ";\n";
                        }
                    }
                    | TK_CONTINUE {
                        compilador.debug("Comando CONTINUE");

                        ControleFluxo* controleFluxo = compilador.getUltimoControleFluxo();

                        if (controleFluxo == NULL) {
                            yyerror("O comando CONTINUE não pode ser usado fora de um loop");
                        }

                        if (controleFluxo->isSwitch()) {
                            yyerror("O comando CONTINUE não pode ser usado dentro de um switch");
                        }

                        $$.traducao = "goto " + controleFluxo->inicioLabel + ";\n";
                    }
                    | TK_SCANF TK_OPEN_PARENTHESIS EXPRESSAO TK_CLOSE_PARENTHESIS {
                        compilador.debug("Comando SCANF");

                        $$.tipo = TIPO_STRING;
                        $$.label = generateName();
                        $$.traducao = $3.traducao;

                        compilador.adicionarVariavel($$.label, $$.label, TIPO_STRING);

                        $$.traducao += "scanf(\"" + $3.label + "\", " + $$.label + ".data);\n";
                    }
                    | TK_PRINTF TK_OPEN_PARENTHESIS EXPRESSAO TK_CLOSE_PARENTHESIS {
                        compilador.debug("Comando PRINTF");

                        $$.tipo = $3.tipo;
                        $$.label = $3.label;
                        $$.traducao = $3.traducao;

                        if ($3.tipo == TIPO_STRING) {
                            $$.traducao += "printf(\"%s\", " + $3.label + ".data);\n";
                        } else if ($3.tipo == TIPO_INT) {
                            $$.traducao += "printf(\"%d\", " + $3.label + ");\n";
                        } else if ($3.tipo == TIPO_FLOAT) {
                            $$.traducao += "printf(\"%f\", " + $3.label + ");\n";
                        } else if ($3.tipo == TIPO_BOOLEAN) {
                            $$.traducao += "printf(\"%d\", " + $3.label + ");\n";
                        } else if ($3.tipo == TIPO_CHAR) {
                            $$.traducao += "printf(\"%c\", " + $3.label + ");\n";
                        } else {
                            yyerror("O comando PRINTF não pode ser usado com o tipo " + $3.tipo);
                        }
                    }
                    | TK_PRINTFLN TK_OPEN_PARENTHESIS EXPRESSAO TK_CLOSE_PARENTHESIS {
                        compilador.debug("Comando PRINTFLN");

                        $$.tipo = $3.tipo;
                        $$.label = $3.label;
                        $$.traducao = $3.traducao;

                        if ($3.tipo == TIPO_STRING) {
                            $$.traducao += "printf(\"%s\\n\", " + $3.label + ".data);\n";
                        } else if ($3.tipo == TIPO_INT) {
                            $$.traducao += "printf(\"%d\\n\", " + $3.label + ");\n";
                        } else if ($3.tipo == TIPO_FLOAT) {
                            $$.traducao += "printf(\"%f\\n\", " + $3.label + ");\n";
                        } else if ($3.tipo == TIPO_BOOLEAN) {
                            $$.traducao += "printf(\"%d\\n\", " + $3.label + ");\n";
                        } else if ($3.tipo == TIPO_CHAR) {
                            $$.traducao += "printf(\"%c\\n\", " + $3.label + ");\n";
                        } else {
                            yyerror("O comando PRINTFLN não pode ser usado com o tipo " + $3.tipo);
                        }
                    }

INICIAR_WHILE: TK_WHILE {
                compilador.adicionarControleFluxo();
            }

INICIAR_DO_WHILE: TK_DO {
                compilador.adicionarControleFluxo();
            }

INICIAR_FOR: TK_FOR {
                compilador.adicionarContexto();
                compilador.adicionarControleFluxo();
            }

FOR_CONDICAO: EXPRESSAO {
                if ($1.tipo != TIPO_BOOLEAN) {
                    yyerror("A expressão lógica do FOR deve ser do tipo booleano");
                }

                $$ = $1;
            }
            | {
                string temp = generateName();
                compilador.adicionarVariavel(temp, temp, TIPO_BOOLEAN);

                $$.label = temp;
                $$.tipo = TIPO_BOOLEAN;
                $$.traducao = temp + " = true;\n";
            }

INICIAR_FOR_ATRIBUICAO_OU_DECLARACAO : DECLARAR_VARIAVEL { $$.traducao = $1.traducao; }
                                    | MULTIPLAS_ATRIBUICOES { $$.traducao = $1.traducao; }
                                    | { $$.traducao = ""; }


MULTIPLAS_ATRIBUICOES: ATRIBUIR_VARIAVEL {
                        $$.traducao = $1.traducao;
                    }
                    | MULTIPLAS_ATRIBUICOES TK_COMMA ATRIBUIR_VARIAVEL {
                        $$.traducao = $1.traducao + $3.traducao;
                    }

MULTIPLAS_EXPRESOES: EXPRESSAO {
                        $$.traducao = $1.traducao;
                    }
                    | MULTIPLAS_EXPRESOES TK_COMMA EXPRESSAO {
                        $$.traducao = $1.traducao + $3.traducao;
                    }
                    | { $$.traducao = ""; }

INICIAR_SWITCH: TK_SWITCH TK_OPEN_PARENTHESIS EXPRESSAO TK_CLOSE_PARENTHESIS {
                compilador.adicionarContexto();
                compilador.adicionarControleFluxo($3.tipo);

                if ($3.tipo == TIPO_STRING) {
                    yyerror("O switch não pode ser usado com expressões do tipo string, por enquanto...");
                }

                $$.traducao = $3.traducao;
                $$.label = $3.label;
                $$.tipo = $3.tipo;
            }

CASO_SWITCH: TK_CASE LITERAIS TK_COLON COMMAND {
                compilador.debug("Caso do switch");

                auto controleFluxo = compilador.getUltimoControleFluxo();

                if (!controleFluxo->isSwitch()) {
                    yyerror("O comando CASE não pode ser usado fora de um switch");
                }

                if ($2.tipo != controleFluxo->switchType) {
                    yyerror("O tipo da expressão do CASE não corresponde ao tipo do switch");
                }

                controleFluxo->adicionarCaso($2.label, $2.traducao, $4.traducao);
            }
            | TK_DEFAULT TK_COLON COMMAND {
                compilador.debug("Caso default do switch");

                auto controleFluxo = compilador.getUltimoControleFluxo();

                if (!controleFluxo->isSwitch()) {
                    yyerror("O comando DEFAULT não pode ser usado fora de um switch");
                }

                if (controleFluxo->hasCasoPadrao()) {
                    yyerror("O switch não pode ter mais de um caso default");
                }

                controleFluxo->adicionarCaso("default", "", $3.traducao);
            }

VARIOS_CASOS_SWITCH: CASO_SWITCH {
                $$.traducao = $1.traducao;
            }
            | VARIOS_CASOS_SWITCH CASO_SWITCH {
                $$.traducao = $1.traducao + $2.traducao;
            }

CASOS_SWITCH: VARIOS_CASOS_SWITCH { $$ = $1; } | { }

CONTROLE_FLUXO: TK_IF TK_OPEN_PARENTHESIS EXPRESSAO TK_CLOSE_PARENTHESIS COMMAND %prec THEN {
                compilador.debug("Controle de fluxo IF");

                if ($3.tipo != TIPO_BOOLEAN) {
                    yyerror("A expressão lógica do IF deve ser do tipo booleano");
                }

                string tempBool = generateName();
                string ifLabel = generateLabel();

                compilador.adicionarVariavel(tempBool, tempBool, TIPO_BOOLEAN);

                $$.traducao = $3.traducao;
                $$.traducao += tempBool + " = !(" + $3.label + ");\n";
                $$.traducao += "if (" + tempBool + ") goto " + ifLabel + ";\n";
                $$.traducao += $5.traducao;
                $$.traducao += ifLabel + ": \n";
            }
            | TK_IF TK_OPEN_PARENTHESIS EXPRESSAO TK_CLOSE_PARENTHESIS COMMAND TK_ELSE COMMAND {
                compilador.debug("Controle de fluxo IF-ELSE");

                if ($3.tipo != TIPO_BOOLEAN) {
                    yyerror("A expressão lógica do IF deve ser do tipo booleano");
                }

                string tempBool = generateName();
                string ifLabel = generateLabel();
                string elseLabel = generateLabel();

                compilador.adicionarVariavel(tempBool, tempBool, TIPO_BOOLEAN);

                $$.traducao = $3.traducao;
                $$.traducao += tempBool + " = !(" + $3.label + ");\n";
                $$.traducao += "if (" + tempBool + ") goto " + elseLabel + ";\n";
                $$.traducao += $5.traducao;
                $$.traducao += "goto " + ifLabel + ";\n";
                $$.traducao += elseLabel + ": \n";
                $$.traducao += $7.traducao;
                $$.traducao += ifLabel + ": \n";

                $$.tipo = TIPO_BOOLEAN;
                $$.label = tempBool;
            }
            | INICIAR_WHILE TK_OPEN_PARENTHESIS EXPRESSAO TK_CLOSE_PARENTHESIS COMMAND {
                compilador.debug("Controle de fluxo WHILE");

                if ($3.tipo != TIPO_BOOLEAN) {
                    yyerror("A expressão lógica do WHILE deve ser do tipo booleano");
                }

                auto controleFluxo = compilador.getUltimoControleFluxo();

                string tempBool = generateName();
                string inicioWhileLabel = controleFluxo->inicioLabel;
                string fimWhileLabel = controleFluxo->fimLabel;

                compilador.adicionarVariavel(tempBool, tempBool, TIPO_BOOLEAN);

                $$.traducao = inicioWhileLabel + ": \n";
                $$.traducao += $3.traducao;
                $$.traducao += tempBool + " = !(" + $3.label + ");\n";
                $$.traducao += "if (" + tempBool + ") goto " + fimWhileLabel + ";\n";
                $$.traducao += $5.traducao;
                $$.traducao += "goto " + inicioWhileLabel + ";\n";
                $$.traducao += fimWhileLabel + ": \n";

                compilador.removerUltimoControleFluxo();
            }
            | INICIAR_DO_WHILE COMMAND TK_WHILE TK_OPEN_PARENTHESIS EXPRESSAO TK_CLOSE_PARENTHESIS {
                compilador.debug("Controle de fluxo DO-WHILE");

                if ($5.tipo != TIPO_BOOLEAN) {
                    yyerror("A expressão lógica do DO-WHILE deve ser do tipo booleano");
                }

                auto controleFluxo = compilador.getUltimoControleFluxo();

                string tempBool = generateName();
                string inicioDoWhileLabel = controleFluxo->inicioLabel;
                string fimDoWhileLabel = controleFluxo->fimLabel;

                compilador.adicionarVariavel(tempBool, tempBool, TIPO_BOOLEAN);

                $$.traducao = $2.traducao;
                $$.traducao += inicioDoWhileLabel + ": \n";
                $$.traducao += $5.traducao;
                $$.traducao += tempBool + " = !(" + $5.label + "); \n";
                $$.traducao += "if (" + tempBool + ") goto " + fimDoWhileLabel + ";\n";
                $$.traducao += $2.traducao;
                $$.traducao += "goto " + inicioDoWhileLabel + ";\n";
                $$.traducao += fimDoWhileLabel + ": \n";

                compilador.removerUltimoControleFluxo();
            }
            | INICIAR_FOR TK_OPEN_PARENTHESIS INICIAR_FOR_ATRIBUICAO_OU_DECLARACAO TK_SEMICOLON FOR_CONDICAO TK_SEMICOLON MULTIPLAS_EXPRESOES TK_CLOSE_PARENTHESIS COMMAND {
                compilador.debug("Controle de fluxo FOR");

                auto controleFluxo = compilador.getUltimoControleFluxo();

                string tempBool = generateName();
                string inicioForLabel = generateLabel();
                string inicioVerificacaoLabel = controleFluxo->inicioLabel;
                string fimForLabel = controleFluxo->fimLabel;

                compilador.adicionarVariavel(tempBool, tempBool, TIPO_BOOLEAN);

                $$.traducao = $3.traducao;
                $$.traducao += inicioForLabel + ": \n";
                $$.traducao += $5.traducao;
                $$.traducao += tempBool + " = !(" + $5.label + "); \n";
                $$.traducao += "if (" + tempBool + ") goto " + fimForLabel + ";\n";
                $$.traducao += $9.traducao;
                $$.traducao += inicioVerificacaoLabel + ":\n";
                $$.traducao += $7.traducao;
                $$.traducao += "goto " + inicioForLabel + ";\n";
                $$.traducao += fimForLabel + ": \n";

                compilador.removerUltimoControleFluxo();
                compilador.removerUltimoContexto();
            }
            | INICIAR_SWITCH TK_OPEN_BRACE CASOS_SWITCH TK_CLOSE_BRACE {
                compilador.debug("Controle de fluxo SWITCH");

                auto controleFluxo = compilador.getUltimoControleFluxo();

                if (!controleFluxo->isSwitch()) {
                    yyerror("O comando SWITCH não pode ser usado fora de um switch");
                }

                if (!controleFluxo->hasPeloMenosUmCaso()) {
                    yyerror("O switch precisa ter pelo menos um caso diferente do caso padrão");
                }

                $$.traducao = $1.traducao + $3.traducao;

                string traducaoDosComandos = "";

                for (auto it = controleFluxo->casos.begin(); it != controleFluxo->casos.end(); ++it) {
                    CasoSwitch* caso = *it;

                    if (caso->label == "default") {
                        continue;
                    }

                    $$.traducao += caso->traducaoExpressao;

                    string casoLabel = generateLabel();
                    string label = generateName();

                    compilador.adicionarVariavel(label, label, TIPO_BOOLEAN);

                    $$.traducao += label + " = " + $1.label + " == " + caso->label + ";\n";
                    $$.traducao += "if (" + label + ")\n";
                    $$.traducao += "goto " + casoLabel + ";\n";

                    traducaoDosComandos += casoLabel + ": \n";
                    traducaoDosComandos += caso->traducaoComando;
                }

                for (CasoSwitch* caso : controleFluxo->casos) {
                    if (caso->label != "default") {
                        continue;
                    }

                    string defaultCasoLabel = generateLabel();

                    $$.traducao += "goto " + defaultCasoLabel + ";\n";
                    traducaoDosComandos += defaultCasoLabel + ": \n";
                    traducaoDosComandos += caso->traducaoComando;
                }

                $$.traducao += traducaoDosComandos;
                $$.traducao += controleFluxo->fimLabel + ": \n";

                compilador.removerUltimoControleFluxo();
            }

// EXPRESSAO:  CONVERSAO_EXPLICITA { $$ = $1; }
EXPRESSAO: OPERADORES_ARITMETICOS { $$ = $1; }
            | OPERADORES_LOGICOS { $$ = $1; }
            | OPERADORES_RELACIONAIS { $$ = $1; }
            | ATRIBUIR_VARIAVEL { $$ = $1; }
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
    exit(1);
}
