#include <iostream>
#include <string>
#include <sstream>
#include <vector>
#include <list>

using namespace std;

#pragma once
namespace compiler {

    class Variavel;
    class Parametro;
    class Funcao;
    class Contexto;
    class ControleFluxo;
    class Compilador;

    int yyerror(string msg);

    const string TIPO_INT = "int";
    const string TIPO_FLOAT = "float";
    const string TIPO_CHAR = "char";
    const string TIPO_BOOLEAN = "bool";
    const string TIPO_STRING = "string";
    const string TIPO_VOID = "void";

    int variableCount = 0;
    int labelCount = 0;
    int funcaoCount = 0;

    string generateName() {
        return "t" + to_string(variableCount++);
    }

    string generateLabel() {
        return "l" + to_string(labelCount++);
    }

    string generateFuncaoName() {
        return "f" + to_string(funcaoCount++);
    }

    list<Variavel*> todasVariaveisJaDeclaradas = list<Variavel*>();

    vector<string> split(string str, string delimiter) {
        size_t pos_start = 0, pos_end, delim_len = delimiter.length();
        string token;
        vector<string> res;

        while ((pos_end = str.find(delimiter, pos_start)) != string::npos) {
            token = str.substr (pos_start, pos_end - pos_start);
            pos_start = pos_end + delim_len;
            res.push_back (token);
        }

        if (pos_start < str.length()) {
            res.push_back (str.substr (pos_start));
        }
        return res;
    } 

    class Variavel {
        public:
            string nome;
            string nomeFicticio;
            string tipo;
            bool array;

            Variavel(string nome, string nomeFicticio, string tipo, bool array = false) {
                this->nome = nome;
                this->nomeFicticio = nomeFicticio;
                this->tipo = tipo;
                this->array = false;
            }
    };

    class Parametro {
        public:
            string nome;
            string nomeFicticio;
            string tipo;

            Parametro(string nome, string nomeFicticio, string tipo) {
                this->nome = nome;
                this->nomeFicticio = nomeFicticio;
                this->tipo = tipo;
            }

            Variavel* getVariavel() {
                return new Variavel(this->nome, this->nomeFicticio, this->tipo);
            }
    };

    class Funcao {
        public:
            string name;
            string nomeFicticio;
            string tipoRetorno;
            list<Parametro*> parametros;
            string traducaoCorpo;

            Funcao(string name, string nomeFicticio, string tipoRetorno) {
                this->name = name;
                this->nomeFicticio = nomeFicticio;
                this->tipoRetorno = tipoRetorno;
                this->parametros = list<Parametro*>();
                this->traducaoCorpo = "";
            }

            Parametro* buscarParametro(string nome) {
                for (list<Parametro*>::iterator it = this->parametros.begin(); it != this->parametros.end(); ++it) {
                    Parametro* parametro = *it;

                    if (parametro->nome == nome) {
                        return parametro;
                    }
                }

                return NULL;
            }

            void adicionarParametro(string nome, string tipo) {
                if (this->buscarParametro(nome) != NULL) {
                    yyerror("O parametro " + nome + " ja foi declarado nessa funcao");
                }

                this->parametros.push_back(new Parametro(nome, "parameter" + to_string(this->parametros.size()), tipo));
            }
            
            string getTraducao() {
                string traducao = "";

                traducao += tipoRetorno + " " + nomeFicticio + "(";

                for (list<Parametro*>::iterator it = this->parametros.begin(); it != this->parametros.end(); ++it) {
                    Parametro* parametro = *it;

                    traducao += parametro->tipo + " " + parametro->nomeFicticio + ", ";
                }

                if (this->parametros.size() > 0) {
                    traducao = traducao.substr(0, traducao.size() - 2);
                }

                traducao += ") {\n";

                vector<string> splitted = split(this->traducaoCorpo, "\n");

                for (string linha : splitted) {
                    traducao += "\t" + linha + "\n";
                }

                traducao += "}\n";

                return traducao;
            }
    };

    class Contexto {
        public:
            vector<Variavel*> variaveis;
            string tipoRetorno;

            Contexto() {
                this->variaveis = vector<Variavel*>();
                this->tipoRetorno = "";
            }

            void adicionarVariavel(Variavel* variavel) {
                this->variaveis.push_back(variavel);
                todasVariaveisJaDeclaradas.push_back(variavel);
            }

            Variavel* buscarVariavel(string nome) {
                for (Variavel* variavel : this->variaveis) {
                    if (variavel->nome == nome) {
                        return variavel;
                    }
                }
                return NULL;
            }

            bool isRetornando() {
                return this->tipoRetorno != "";
            }
    };

    class CasoSwitch {
        public:
            string label;
            string traducaoExpressao;
            string traducaoComando;

            CasoSwitch(string label, string traducaoExpressao, string traducaoComando) {
                this->label = label;
                this->traducaoExpressao = traducaoExpressao;
                this->traducaoComando = traducaoComando;
            }
    };

    class ControleFluxo {
        public:
            string inicioLabel;
            string fimLabel;
            string switchType;
            list<CasoSwitch*> casos;

            ControleFluxo(string switchType) {
                this->inicioLabel = generateLabel();
                this->fimLabel = generateLabel();
                this->switchType = switchType;
                this->casos = list<CasoSwitch*>();
            }

            bool hasCasoPadrao() {
                for (CasoSwitch* caso : this->casos) {
                    if (caso->label == "default") {
                        return true;
                    }
                }
                return false;
            }

            bool hasPeloMenosUmCaso() {
                int casos = 0;

                for (CasoSwitch* caso : this->casos) {
                    if (caso->label != "default") {
                        casos++;
                    }
                }

                return casos > 0;
            }

            void adicionarCaso(string label, string traducaoExpressao, string traducaoComando) {
                this->casos.push_back(new CasoSwitch(label, traducaoExpressao, traducaoComando));
            }

            bool isSwitch() {
                return this->switchType != "";
            }
    };

    class Compilador {
        private:
            list<Contexto*> contextos;
            list<ControleFluxo*> controleFluxo;
            list<Funcao*> funcoes;
            Funcao* funcaoAtual;
            bool debugMode;
            
        public:

            Compilador() {
                this->contextos = list<Contexto*>();
                this->contextos.push_back(new Contexto());
                this->controleFluxo = list<ControleFluxo*>();
                this->funcoes = list<Funcao*>();
                this->funcaoAtual = NULL;
                this->debugMode = true;
            }

            void compilar(string codigo) {
                string codigoGerado = "";

                codigoGerado += "#include <stdlib.h>\n";
                codigoGerado += "#include <stdio.h>\n";
                codigoGerado += "#include <string.h>\n";
                codigoGerado += "\n";
                codigoGerado += "#define bool char\n";
                codigoGerado += "#define true 1\n";
                codigoGerado += "#define false 0\n";
                codigoGerado += "\n";

                codigoGerado += "typedef struct {\n";
                codigoGerado += "\tchar* data;\n";
                codigoGerado += "\tint length;\n";
                codigoGerado += "} string;\n\n";

                vector<string> splitted = split(codigo, "\n");

                for (Variavel* variavel : todasVariaveisJaDeclaradas) {
                    codigoGerado += variavel->tipo + " " + variavel->nomeFicticio + ";\n";
                }

                codigoGerado += "\n";

                for (Funcao* funcao : this->funcoes) {
                    codigoGerado += funcao->getTraducao();
                }

                codigoGerado += "\n";
                codigoGerado += "int main(void) {\n";
                
                for (int i = 0; i < splitted.size(); i++) {
                    codigoGerado += "\t" + splitted[i] + "\n";
                }

                codigoGerado += "\treturn 0;\n";
                codigoGerado += "}";

                cout << codigoGerado << endl;
            }

            ControleFluxo* adicionarControleFluxo(string switchType = "") {
                ControleFluxo* controleFluxo = new ControleFluxo(switchType);
                this->controleFluxo.push_back(controleFluxo);
                return controleFluxo;
            }

            ControleFluxo* removerUltimoControleFluxo() {
                ControleFluxo* controleFluxo = this->controleFluxo.back();
                this->controleFluxo.pop_back();
                return controleFluxo;
            }

            ControleFluxo* getUltimoControleFluxo() {
                return this->controleFluxo.back();
            }

            Contexto* adicionarContexto() {
                Contexto* contexto = new Contexto();
                this->contextos.push_back(contexto);
                return contexto;
            }

            Contexto* removerUltimoContexto() {
                Contexto* contexto = this->contextos.back();
                this->contextos.pop_back();
                return contexto;
            }

            Contexto* getContextoAtual() {
                return this->contextos.back();
            }

            Variavel* buscarVariavel(string nome) {
                for (auto it = this->contextos.rbegin(); it != this->contextos.rend(); ++it) {
                    Variavel* variavel = (*it)->buscarVariavel(nome);
                    if (variavel != NULL) {
                        return variavel;
                    }
                }
                return NULL;
            }

            void adicionarVariavel(string nome, string nomeFicticio, string tipo, bool array = false) {
                Variavel* variavel = new Variavel(nome, nomeFicticio, tipo, array);
                this->contextos.back()->adicionarVariavel(variavel);
            }

            Funcao* buscarFuncao(string nome) {
                for (Funcao* funcao : this->funcoes) {
                    if (funcao->name == nome) {
                        return funcao;
                    }
                }

                return NULL;
            }

            void adicionarFuncao(Funcao* funcao) {
                this->funcoes.push_back(funcao);
            }

            bool isCriandoFuncao() {
                return this->funcaoAtual != NULL;
            }

            void setFuncaoAtual(Funcao* funcao) {
                this->funcaoAtual = funcao;
            }

            Funcao* getFuncaoAtual() {
                return this->funcaoAtual;
            }

            void debug(string message) {
                if (this->debugMode) {
                    cout << "// Debug: " << message << endl;
                }
            }

            bool isArithmetic(string tipo) {
                return tipo == TIPO_INT || tipo == TIPO_FLOAT;
            }
    };

    int yyerror(string msg) {
        cout << "Erro: " << msg << endl;
        exit(1);
    }
}