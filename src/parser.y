%{
#include <iostream>
#include <string>
#include <sstream>
#include "../src/compiler.h"
#include <map>

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
%}

%token TK_SEMICOLON TK_COLON TK_COMMA TK_OPEN_PARENTHESIS TK_CLOSE_PARENTHESIS TK_OPEN_BRACE TK_CLOSE_BRACE
%token TK_VAR TK_DO TK_WHILE TK_FOR TK_SWITCH TK_CASE TK_DEFAULT TK_CONTINUE TK_BREAK TK_IF
%token TK_ELSE TK_RETURN TK_FUNCTION TK_ARROW TK_AND TK_OR TK_NOT TK_PLUS TK_MINUS TK_MULT TK_SCANF TK_PRINTF TK_PRINTFLN
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
%left TK_CLOSE_PARENTHESIS

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
        | DECLARAR_VARIAVEL TK_SEMICOLON { $$ = $1; }
        | ATRIBUIR_VARIAVEL TK_SEMICOLON { $$ = $1; }
        | COMANDOS_CUSTOMIZADOS TK_SEMICOLON { $$ = $1; }
        | EXPRESSAO TK_SEMICOLON { $$ = $1; }
        | DECLARAR_FUNCAO { $$ = $1; }
        | CONTROLE_FLUXO { $$ = $1; }

CRIAR_CONTEXTO: TK_OPEN_BRACE { compilador.debug("Criando contexto"); compilador.adicionarContexto(); }

ENCERRAR_CONTEXTO: TK_CLOSE_BRACE { compilador.debug("Encerrando contexto"); compilador.removerUltimoContexto(); }

DECLARAR_VARIAVEL: TK_VAR TK_ID TK_ASSIGN EXPRESSAO {
                    compilador.debug("Declarando variável " + $2.label + " do tipo " + $4.tipo + " com valor " + $4.label);

                    auto var = compilador.getContextoAtual()->buscarVariavel($2.label);

                    if (var != NULL) {
                        yyerror("A variável \"" + $2.label + "\" já foi declarada nesse contexto");
                    }

                    if (compilador.isCriandoFuncao()) {
                        Funcao* funcao = compilador.getFuncaoAtual();

                        Parametro* parametro = funcao->buscarParametro($2.label);

                        if (parametro != NULL) {
                            yyerror("Conflito de nome entre o parametro \"" + $2.label + "\" e a variável \"" + $2.label + "\" declarada nessa função");
                        }
                    }

                    string nomeFicticio = generateName();

                    compilador.adicionarVariavel($2.label, nomeFicticio, $4.tipo);

                    $$.label = nomeFicticio;
                    $$.tipo = $4.tipo;
                    $$.traducao = $4.traducao;

                    if ($4.tipo == TIPO_STRING) {
                        string temp = generateName();

                        compilador.adicionarVariavel(temp, temp, TIPO_INT);
                        $$.traducao += temp + " = " + $4.label + ".length + 1;\n";

                        $$.traducao += $$.label + ".data = (char*) malloc(" + temp + ");\n";
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
                        yyerror("O tipo da variável \"" + $2.label + "\" (" + $4.label + ") não corresponde ao tipo declarado (" + $6.tipo + ")");
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
                        string temp = generateName();
                        compilador.adicionarVariavel(temp, temp, TIPO_INT);
                        $$.traducao += temp + " = " + $6.label + ".length + 1;\n";

                        $$.traducao += $$.label + ".data = (char*) malloc(" + temp + ");\n";
                        $$.traducao += "strcpy(" + $$.label + ".data, " + $6.label + ".data);\n";
                        $$.traducao += $$.label + ".length = " + $6.label + ".length;\n";
                    } else {
                        $$.traducao += $$.label + " = " + $6.label + ";\n";
                    }
                }

ATRIBUIR_VARIAVEL: TK_ID TK_ASSIGN EXPRESSAO {
                    compilador.debug("Atribuindo variável " + $1.label + " do tipo " + $3.tipo + " com valor " + $3.label);

                    auto var = compilador.buscarVariavel($1.label);

                    if (var == NULL && !compilador.isCriandoFuncao()) {
                        if (compilador.isCriandoFuncao()) {
                            Funcao* funcao = compilador.getFuncaoAtual();

                            Parametro* parametro = funcao->buscarParametro($1.label);

                            if (parametro == NULL) {
                                yyerror("Não foi possível encontrar a variável \"" + $1.label + "\"");
                            }

                            var = parametro->getVariavel();
                        }
                    }

                    if (var->tipo != $3.tipo) {
                        yyerror("O tipo da variável \"" + $1.label + "\" (" + var->tipo + ") não corresponde ao tipo da expressão (" + $3.tipo + ")");
                    }

                    $$.traducao = $3.traducao;

                    if (var->tipo == TIPO_STRING) {
                        string temp = generateName();
                        compilador.adicionarVariavel(temp, temp, TIPO_INT);
                        $$.traducao += temp + " = " + $3.label + ".length + 1;\n";

                        $$.traducao += var->nomeFicticio + ".data = (char*) malloc(" + temp + ");\n";
                        $$.traducao += "strcpy(" + var->nomeFicticio + ".data, " + $3.label + ".data);\n";
                        $$.traducao += var->nomeFicticio + ".length = " + $3.label + ".length;\n";
                    } else {
                        $$.traducao += var->nomeFicticio + " = " + $3.label + ";\n";
                    }

                    $$.label = $1.label;
                    $$.tipo = $3.tipo;
                }

INICIAR_DECLARACAO_FUNCAO: TK_FUNCTION TK_ID {
            compilador.debug("Iniciando declaração de função " + $2.label);

            if (compilador.isCriandoFuncao()) {
                yyerror("Não é possível declarar uma função dentro de outra função");
            }

            Funcao* funcao = new Funcao($2.label, generateFuncaoName(), TIPO_VOID);

            compilador.adicionarContexto();
            compilador.setFuncaoAtual(funcao);
        }

TODOS_PARAMETROS_FUNCAO: TK_OPEN_PARENTHESIS PARAMETROS_FUNCAO TK_CLOSE_PARENTHESIS TK_ARROW TK_TYPE {
            compilador.debug("Todos os parâmetros da função");

            Funcao* funcao = compilador.getFuncaoAtual();

            funcao->tipoRetorno = $5.label;
        }
        | TK_OPEN_PARENTHESIS PARAMETROS_FUNCAO TK_CLOSE_PARENTHESIS {
            Funcao* funcao = compilador.getFuncaoAtual();
            
            funcao->tipoRetorno = TIPO_VOID;
        }

PARAMETROS_FUNCAO: PARAMETRO_FUNCAO {}
        | PARAMETROS_FUNCAO TK_COMMA PARAMETRO_FUNCAO {}
        | {}

PARAMETRO_FUNCAO: TK_TYPE TK_ID {
            Funcao* funcao = compilador.getFuncaoAtual();
            
            funcao->adicionarParametro($2.label, $1.label);
        }

CORPO_FUNCAO: TK_OPEN_BRACE COMMANDS TK_CLOSE_BRACE {
            compilador.debug("Corpo da função");
            
            Funcao* funcao = compilador.getFuncaoAtual();
            
            funcao->traducaoCorpo = $2.traducao;
        }

DECLARAR_FUNCAO: INICIAR_DECLARACAO_FUNCAO TODOS_PARAMETROS_FUNCAO CORPO_FUNCAO {
            compilador.debug("Declarando função " + $2.label);

            Funcao* funcao = compilador.getFuncaoAtual();
            Contexto* contexto = compilador.getContextoAtual();

            if (funcao->tipoRetorno == TIPO_VOID) {
                if (contexto->isRetornando()) {
                    yyerror("A função " + funcao->name + " não espera um valor de retorno, mas há um valor sendo retornado que é do tipo " + contexto->tipoRetorno);
                }
            } else {
                if (!contexto->isRetornando()) {
                    yyerror("A função " + funcao->name + " espera um valor de retorno, mas em seu corpo não há um comando de retorno");
                }

                if (contexto->tipoRetorno != funcao->tipoRetorno) {
                    if (compilador.isArithmetic(contexto->tipoRetorno) && compilador.isArithmetic(funcao->tipoRetorno)) {
                        yyerror("A função " + funcao->name + " espera um valor de retorno do tipo " + funcao->tipoRetorno + ", mas o valor retornado é do tipo " + contexto->tipoRetorno + ". Para o caso específico de tipos aritméticos, o valor retornado precisará ser explicitamente convertido para o tipo esperado da função (" + funcao->tipoRetorno + ")");
                    } else {
                        yyerror("A função " + funcao->name + " espera um valor de retorno do tipo " + funcao->tipoRetorno + ", mas o valor retornado é do tipo " + contexto->tipoRetorno);
                    }
                }
            }

            compilador.adicionarFuncao(funcao);
            compilador.setFuncaoAtual(NULL);
            compilador.removerUltimoContexto();

            $$.traducao = "";
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
                    | TK_RETURN {
                        compilador.debug("Comando RETURN");

                        Funcao* funcao = compilador.getFuncaoAtual();

                        if (funcao == NULL) {
                            yyerror("O comando RETURN não pode ser usado fora de uma função");
                        }

                        if (funcao->tipoRetorno != TIPO_VOID) {
                            yyerror("A função " + funcao->name + " espera um valor de retorno do tipo " + funcao->tipoRetorno + ", mas o comando de retorno atual não retorna nenhum valor");
                        }

                        $$.traducao = "return;\n";
                    }
                    | TK_RETURN EXPRESSAO {
                        compilador.debug("Comando RETURN");

                        Funcao* funcao = compilador.getFuncaoAtual();

                        if (funcao == NULL) {
                            yyerror("O comando RETURN não pode ser usado fora de uma função");
                        }

                        if (funcao->tipoRetorno != TIPO_VOID && funcao->tipoRetorno != $2.tipo) {
                            yyerror("O tipo de retorno da função (" + funcao->tipoRetorno + ") não corresponde ao tipo da expressão (" + $2.tipo + ")");
                        }

                        Contexto* contexto = compilador.getContextoAtual();

                        contexto->tipoRetorno = $2.tipo;

                        $$.traducao = $2.traducao;
                        $$.traducao += "return " + $2.label + ";\n";
                    }
                    | TK_SCANF TK_OPEN_PARENTHESIS EXPRESSAO TK_CLOSE_PARENTHESIS {
                        compilador.debug("Comando SCANF");

                        if ($3.tipo != TIPO_STRING) {
                            yyerror("O comando SCANF precisa ser usado com uma variável do tipo string");
                        }

                        string temp = generateName();
                        string temp2 = generateName();
                        string temp3 = generateName();
                        string temp4 = generateName();
                        string temp5 = generateName();
                        string temp6 = generateName();
                        string temp7 = generateName();
                        string temp8 = generateName();
                        string temp9 = generateName();

                        compilador.adicionarVariavel(temp, temp, TIPO_INT);
                        compilador.adicionarVariavel(temp2, temp2, TIPO_INT);
                        compilador.adicionarVariavel(temp3, temp3, TIPO_INT);
                        compilador.adicionarVariavel(temp4, temp4, TIPO_INT);
                        compilador.adicionarVariavel(temp5, temp5, TIPO_INT);
                        compilador.adicionarVariavel(temp6, temp6, TIPO_INT);
                        compilador.adicionarVariavel(temp7, temp7, TIPO_INT);
                        compilador.adicionarVariavel(temp8, temp8, TIPO_INT);
                        compilador.adicionarVariavel(temp9, temp9, TIPO_INT);

                        string inicioLoop = generateLabel();
                        string fimLoop = generateLabel();
                        string redimensionar = generateLabel();
                        string continuarLoop = generateLabel();
                        string fimRedimensionar = generateLabel();

                        $$.traducao = $3.traducao;
                        $$.traducao += temp + " = 32;\n"; // tamanho inicial
                        $$.traducao += temp2 + " = 0;\n"; // posição atual
                        $$.traducao += temp3 + " = 0;\n"; // caractere lido
                        $$.traducao += temp4 + " = 0;\n"; // flag de fim
                        $$.traducao += temp5 + " = 0;\n"; // tamanho atual
                        
                        // Aloca o buffer inicial
                        $$.traducao += $3.label + ".data = (char*)malloc(" + temp + ");\n";
                        $$.traducao += $3.label + ".length = 0;\n";
                        
                        // Loop de leitura
                        $$.traducao += inicioLoop + ":\n";
                        $$.traducao += temp3 + " = getchar();\n";
                        
                        // Verifica se é newline ou EOF
                        $$.traducao += temp4 + " = " + temp3 + " == '\\n';\n";
                        $$.traducao += temp5 + " = " + temp3 + " == EOF;\n";
                        $$.traducao += temp6 + " = " + temp4 + " || " + temp5 + ";\n";
                        $$.traducao += "if (" + temp6 + ") goto " + fimLoop + ";\n";
                        
                        // Verifica se precisa redimensionar
                        $$.traducao += temp7 + " = " + temp2 + " >= " + temp + " - 1;\n";
                        $$.traducao += "if (" + temp7 + ") goto " + redimensionar + ";\n";
                        $$.traducao += "goto " + continuarLoop + ";\n";
                        
                        // Redimensiona o buffer
                        $$.traducao += redimensionar + ":\n";
                        $$.traducao += temp + " = " + temp + " * 2;\n";
                        $$.traducao += $3.label + ".data = (char*)realloc(" + $3.label + ".data, " + temp + ");\n";
                        $$.traducao += "goto " + continuarLoop + ";\n";
                        
                        // Continua o loop
                        $$.traducao += continuarLoop + ":\n";
                        $$.traducao += $3.label + ".data[" + temp2 + "] = " + temp3 + ";\n";
                        $$.traducao += temp2 + " = " + temp2 + " + 1;\n";
                        $$.traducao += temp3 + " = " + temp3 + " + 1;\n";
                        $$.traducao += "goto " + inicioLoop + ";\n";
                        
                        // Fim do loop
                        $$.traducao += fimLoop + ":\n";
                        $$.traducao += $3.label + ".data[" + temp2 + "] = '\\0';\n";
                        $$.traducao += $3.label + ".length = " + temp3 + ";\n";
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

EXPRESSAO: CONVERSAO_EXPLICITA { $$ = $1; }
            | OPERADORES_ARITMETICOS { $$ = $1; }
            | OPERADORES_LOGICOS { $$ = $1; }
            | OPERADORES_RELACIONAIS { $$ = $1; }
            | LITERAIS { $$.traducao = $1.traducao; }
            | TK_OPEN_PARENTHESIS EXPRESSAO TK_CLOSE_PARENTHESIS { $$ = $2; }
            | CHAMADA_FUNCAO { $$.traducao = $1.traducao; }
            | PRIMARIA { $$.traducao = $1.traducao; }

CHAMADA_FUNCAO: TK_ID TK_OPEN_PARENTHESIS LISTA_ARGUMENTOS TK_CLOSE_PARENTHESIS {
                compilador.debug("Chamando função");

                Funcao* funcao = compilador.buscarFuncao($1.label);

                if (funcao == NULL) {
                    yyerror("Nenhuma função com o nome '" + $1.label + "' foi declarada");
                }

                vector<string> argumentos_partes = split($3.label, ";");
                vector<string> tipos_partes = split($3.tipo, ";");

                vector<string> argumentosPorNome = split(argumentos_partes[0], ",");
                vector<string> argumentosTiposPorNome = split(tipos_partes[0], ",");

                vector<string> argumentosPorPosicao;
                vector<string> argumentosTiposPorPosicao;
                if (argumentos_partes.size() > 1) {
                    argumentosPorPosicao = split(argumentos_partes[1], ",");
                    argumentosTiposPorPosicao = split(tipos_partes[1], ",");
                }

                int totalArgumentos = argumentosPorNome.size() + argumentosPorPosicao.size();

                if (totalArgumentos != funcao->parametros.size()) {
                    yyerror("A função " + funcao->name + " espera " + to_string(funcao->parametros.size()) + " argumento(s), mas foi(ram) passado(s) " + to_string(totalArgumentos) + " argumento(s)");
                }

                map<string, string> argumentosMapeados;

                for (size_t i = 0; i < argumentosPorNome.size(); ++i) { 
                    string argumentoNome = argumentosPorNome[i];
                    string argumentoTipo = argumentosTiposPorNome[i];
                    bool encontrado = false;
                    for (Parametro* parametro : funcao->parametros) {
                        if (parametro->nome == argumentoNome) {
                            if (parametro->tipo != argumentoTipo) {
                                yyerror("O tipo do argumento nomeado '" + argumentoNome + "' (" + argumentoTipo + ") não corresponde ao tipo do parâmetro '" + parametro->nome + "' (" + parametro->tipo + ") na função " + funcao->name);
                            }
                            argumentosMapeados[argumentoNome] = argumentoNome;
                            encontrado = true;
                            break;
                        }
                    }
                    if (!encontrado) {
                        yyerror("O argumento nomeado '" + argumentoNome + "' não é um parâmetro da função " + funcao->name);
                    }
                }

                int idxPosicional = 0;
                for (Parametro* parametro : funcao->parametros) {
                    if (argumentosMapeados.find(parametro->nome) == argumentosMapeados.end()) {
                        if (idxPosicional >= argumentosPorPosicao.size()) {
                            yyerror("Argumento posicional faltando para o parâmetro '" + parametro->nome + "' na função " + funcao->name);
                        }
                        string argumentoValor = argumentosPorPosicao[idxPosicional];
                        string argumentoTipo = argumentosTiposPorPosicao[idxPosicional];

                        if (parametro->tipo != argumentoTipo) {
                            yyerror("O tipo do argumento posicional '" + argumentoValor + "' (" + argumentoTipo + ") não corresponde ao tipo do parâmetro '" + parametro->nome + "' (" + parametro->tipo + ") na função " + funcao->name);
                        }
                        argumentosMapeados[parametro->nome] = argumentoValor;
                        idxPosicional++;
                    }
                }
                
                if (idxPosicional < argumentosPorPosicao.size()) {
                    yyerror("Número excessivo de argumentos posicionais passados para a função " + funcao->name);
                }

                $$.traducao = $3.traducao;

                if (funcao->tipoRetorno != TIPO_VOID) {
                    string temp = generateName();

                    compilador.adicionarVariavel(temp, temp, funcao->tipoRetorno);

                    $$.traducao += temp + " = ";
                    $$.label = temp;
                }

                $$.traducao += funcao->nomeFicticio + "(";
                
                auto it = funcao->parametros.begin();
                for (size_t i = 0; i < funcao->parametros.size(); ++i) {
                    Parametro* parametro = *it;
                    $$.traducao += argumentosMapeados[parametro->nome];
                    if (i < funcao->parametros.size() - 1) {
                        $$.traducao += ", ";
                    }
                    ++it;
                }
                $$.traducao += ");\n";

                $$.tipo = funcao->tipoRetorno;
            }

LISTA_ARGUMENTOS: LISTA_ARGUMENTOS_POR_NOME TK_SEMICOLON LISTA_ARGUMENTOS_POR_POSICAO {
                    $$.label = $1.label + ";" + $3.label;
                    $$.tipo = $1.tipo + ";" + $3.tipo;
                    $$.traducao = $1.traducao + $3.traducao;
                }
                | LISTA_ARGUMENTOS_POR_NOME {
                    $$.label = $1.label + ";";
                    $$.tipo = $1.tipo + ";";
                    $$.traducao = $1.traducao;
                }
                | LISTA_ARGUMENTOS_POR_POSICAO {
                    $$.label = ";" + $1.label;
                    $$.tipo = ";" + $1.tipo;
                    $$.traducao = $1.traducao;
                }
                | {
                    $$.label = ";";
                    $$.tipo = ";";
                    $$.traducao = "";
                }

LISTA_ARGUMENTOS_POR_NOME: ARGUMENTO_POR_NOME {
                                $$.label = $1.label;
                                $$.tipo = $1.tipo;
                                $$.traducao = $1.traducao;
                            }
                            | LISTA_ARGUMENTOS_POR_NOME TK_COMMA ARGUMENTO_POR_NOME {
                                $$.label = $1.label + "," + $3.label;
                                $$.tipo = $1.tipo + "," + $3.tipo;
                                $$.traducao = $1.traducao + $3.traducao;
                            }

ARGUMENTO_POR_NOME: TK_ID TK_ASSIGN EXPRESSAO %prec TK_ASSIGN {
                        compilador.debug("Passando argumento por nome " + $1.label + " (" + $3.tipo + ")");

                        $$.tipo = $3.tipo;
                        $$.label = $3.label;
                        $$.traducao = $3.traducao;
                    }

LISTA_ARGUMENTOS_POR_POSICAO: ARGUMENTO_POR_POSICAO {
                                $$.label = $1.label;
                                $$.tipo = $1.tipo;
                                $$.traducao = $1.traducao;
                            }
                            | LISTA_ARGUMENTOS_POR_POSICAO TK_COMMA ARGUMENTO_POR_POSICAO {
                                $$.label = $1.label + "," + $3.label;
                                $$.tipo = $1.tipo + "," + $3.tipo;
                                $$.traducao = $1.traducao + $3.traducao;
                            }

ARGUMENTO_POR_POSICAO: EXPRESSAO {
                        compilador.debug("Passando argumento por posição " + $1.label + " (" + $1.tipo + ")");

                        $$.tipo = $1.tipo;
                        $$.label = $1.label;
                        $$.traducao = $1.traducao;
                    }

CONVERSAO_EXPLICITA: TK_OPEN_PARENTHESIS TK_TYPE TK_CLOSE_PARENTHESIS EXPRESSAO {
                        compilador.debug("Convertendo expressão " + $4.label + " para tipo " + $2.label);

                        $$.traducao = $4.traducao;
                        
                        if ($2.label == $4.tipo) {
                            compilador.debug("Expressão já é do tipo " + $2.label + ", não é necessário converter");

                            $$.tipo = $2.label;
                            $$.label = $4.label;
                        } else {
                            if ($4.tipo == TIPO_STRING || $2.label == TIPO_STRING) {
                                yyerror("Não é possível converter uma string para outro tipo");
                            }

                            string temp = generateName();
                            compilador.adicionarVariavel(temp, temp, $2.label);

                            if ($2.label == TIPO_BOOLEAN) {
                                string ifLabel = generateName();
                                string ifGotoLabel = generateLabel();
                                string elseGotoLabel = generateLabel();

                                compilador.adicionarVariavel(ifLabel, ifLabel, TIPO_BOOLEAN);

                                $$.traducao += ifLabel + " = " + $4.label + " != 0;\n";
                                $$.traducao += "if (" + ifLabel + ") goto " + ifGotoLabel + ";\n";
                                $$.traducao += temp + " = false;\n";
                                $$.traducao += "goto " + elseGotoLabel + ";\n";
                                $$.traducao += ifGotoLabel + ": \n";
                                $$.traducao += temp + " = true;\n";
                                $$.traducao += elseGotoLabel + ": \n";
                            } else {
                                $$.traducao += temp + " = (" + $2.label + ")" + $4.label + ";\n";
                            }

                            $$.tipo = $2.label;
                            $$.label = temp;
                        }
                    }

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
                    | TK_MINUS EXPRESSAO {
                        compilador.debug("Negando expressão " + $2.label + " (" + $2.tipo + ")");
                        
                        if (!compilador.isArithmetic($2.tipo)) {
                            yyerror("Operadores aritméticos só podem ser aplicados a tipos numéricos");
                        }

                        string nomeFicticio = generateName();

                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, $2.tipo);

                        $$.traducao = $2.traducao;
                        $$.traducao += nomeFicticio + " = -" + $2.label + ";\n";
                        $$.tipo = $2.tipo;
                        $$.label = nomeFicticio;
                    }
                    | TK_PLUS EXPRESSAO {
                        compilador.debug("Operador unário mais");
                        
                        if (!compilador.isArithmetic($2.tipo)) {
                            yyerror("Operadores aritméticos só podem ser aplicados a tipos numéricos");
                        }

                        string nomeFicticio = generateName();

                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, $2.tipo);

                        $$.traducao = $2.traducao;
                        $$.traducao += nomeFicticio + " = " + $2.label + ";\n";
                        $$.tipo = $2.tipo;
                        $$.label = nomeFicticio;
                    }

OPERADORES_RELACIONAIS: EXPRESSAO TK_EQ EXPRESSAO {
                        compilador.debug("Comparando expressão " + $1.label + " (" + $1.tipo + ") com expressão " + $3.label + " (" + $3.tipo + ")");
                        
                        if (!compilador.isArithmetic($1.tipo) || !compilador.isArithmetic($3.tipo)) {
                            yyerror("Esse operador relacional só pode ser aplicado a tipos numéricos");
                        }

                        string temp1 = $1.label;
                        string temp2 = $3.label;

                        string tipoFinal = $1.tipo == $3.tipo ? $1.tipo : TIPO_FLOAT;

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

                        string nomeFicticio = generateName();

                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, TIPO_BOOLEAN);

                        $$.traducao += nomeFicticio + " = " + temp1 + " == " + temp2 + ";\n";
                        $$.tipo = TIPO_BOOLEAN;
                        $$.label = nomeFicticio;
                    }
                    | EXPRESSAO TK_NE EXPRESSAO {
                        compilador.debug("Comparando expressão " + $1.label + " (" + $1.tipo + ") com expressão " + $3.label + " (" + $3.tipo + ")");

                        if (!compilador.isArithmetic($1.tipo) || !compilador.isArithmetic($3.tipo)) {
                            yyerror("Esse operador relacional só pode ser aplicado a tipos numéricos");
                        }
                        
                        string temp1 = $1.label;
                        string temp2 = $3.label;

                        string tipoFinal = $1.tipo == $3.tipo ? $1.tipo : TIPO_FLOAT;

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

                        string nomeFicticio = generateName();
                        
                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, TIPO_BOOLEAN);

                        $$.traducao += nomeFicticio + " = " + temp1 + " != " + temp2 + ";\n";
                        $$.tipo = TIPO_BOOLEAN;
                        $$.label = nomeFicticio;
                    }
                    | EXPRESSAO TK_GT EXPRESSAO {
                        compilador.debug("Comparando expressão " + $1.label + " (" + $1.tipo + ") com expressão " + $3.label + " (" + $3.tipo + ")");

                        if (!compilador.isArithmetic($1.tipo) || !compilador.isArithmetic($3.tipo)) {
                            yyerror("Esse operador relacional só pode ser aplicado a tipos numéricos");
                        }

                        string temp1 = $1.label;
                        string temp2 = $3.label;
                        
                        string tipoFinal = $1.tipo == $3.tipo ? $1.tipo : TIPO_FLOAT;
                        $$.traducao = $1.traducao + $3.traducao;

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

                        string nomeFicticio = generateName();

                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, TIPO_BOOLEAN);

                        $$.traducao += nomeFicticio + " = " + temp1 + " > " + temp2 + ";\n";
                        $$.tipo = TIPO_BOOLEAN;
                        $$.label = nomeFicticio;
                    }
                    | EXPRESSAO TK_LT EXPRESSAO {
                        compilador.debug("Comparando expressão " + $1.label + " (" + $1.tipo + ") com expressão " + $3.label + " (" + $3.tipo + ")");

                        if (!compilador.isArithmetic($1.tipo) || !compilador.isArithmetic($3.tipo)) {
                            yyerror("Esse operador relacional só pode ser aplicado a tipos numéricos");
                        }

                        string temp1 = $1.label;
                        string temp2 = $3.label;
                        
                        string tipoFinal = $1.tipo == $3.tipo ? $1.tipo : TIPO_FLOAT;
                        $$.traducao = $1.traducao + $3.traducao;

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

                        string nomeFicticio = generateName();

                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, TIPO_BOOLEAN);

                        $$.traducao += nomeFicticio + " = " + temp1 + " < " + temp2 + ";\n";
                        $$.tipo = TIPO_BOOLEAN;
                        $$.label = nomeFicticio;
                    }
                    | EXPRESSAO TK_GE EXPRESSAO {
                        compilador.debug("Comparando expressão " + $1.label + " (" + $1.tipo + ") com expressão " + $3.label + " (" + $3.tipo + ")");

                        if (!compilador.isArithmetic($1.tipo) || !compilador.isArithmetic($3.tipo)) {
                            yyerror("Esse operador relacional só pode ser aplicado a tipos numéricos");
                        }

                        string temp1 = $1.label;
                        string temp2 = $3.label;
                        
                        string tipoFinal = $1.tipo == $3.tipo ? $1.tipo : TIPO_FLOAT;
                        $$.traducao = $1.traducao + $3.traducao;

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

                        string nomeFicticio = generateName();

                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, TIPO_BOOLEAN);

                        $$.traducao += nomeFicticio + " = " + temp1 + " >= " + temp2 + ";\n";
                        $$.tipo = TIPO_BOOLEAN;
                        $$.label = nomeFicticio;
                    }
                    | EXPRESSAO TK_LE EXPRESSAO {
                        compilador.debug("Comparando expressão " + $1.label + " (" + $1.tipo + ") com expressão " + $3.label + " (" + $3.tipo + ")");

                        if (!compilador.isArithmetic($1.tipo) || !compilador.isArithmetic($3.tipo)) {
                            yyerror("Esse operador relacional só pode ser aplicado a tipos numéricos");
                        }

                        string temp1 = $1.label;
                        string temp2 = $3.label;
                        
                        string tipoFinal = $1.tipo == $3.tipo ? $1.tipo : TIPO_FLOAT;
                        $$.traducao = $1.traducao + $3.traducao;

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

                        string nomeFicticio = generateName();

                        compilador.adicionarVariavel(nomeFicticio, nomeFicticio, TIPO_BOOLEAN);

                        $$.traducao += nomeFicticio + " = " + temp1 + " <= " + temp2 + ";\n";
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

            $$.traducao = $$.label + ".data = (char*)malloc(" + to_string(size) + ");\n";

            for (int i = 0; i < size - 1; i++) {
                $$.traducao += $$.label + ".data[" + to_string(i) + "] = '" + $1.label[i + 1] + "';\n";
            }

            $$.traducao += $$.label + ".data[" + to_string(size - 1) + "] = '\\0';\n";

            $$.traducao += $$.label + ".length = " + to_string(size - 1) + ";\n";

            compilador.adicionarVariavel($$.label, $$.label, $$.tipo);
        }

PRIMARIA: TK_ID {
            compilador.debug("Buscando variável " + $1.label);

            Funcao* funcao = compilador.getFuncaoAtual();
            Variavel* var = NULL;

            if (funcao != NULL) {
                Parametro* parametro = funcao->buscarParametro($1.label);

                if (parametro != NULL) {
                    var = parametro->getVariavel();
                }
            }

            if (var == NULL) {
                var = compilador.buscarVariavel($1.label);

                if (var == NULL) {
                    yyerror("Não foi possível encontrar a variável \"" + $1.label + "\"");
                }
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