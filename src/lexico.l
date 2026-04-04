%{
/*
 * lexico.l
 * Analizador lexico SPL-NB64
 * Uso: ./lexico programa.spl
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef enum {
    TK_EOF=0,
    /* Palabras reservadas SPL */
    TK_INT, TK_FLOAT, TK_VOID, TK_ARRAY, TK_MATRIX, TK_STRUCT,
    TK_IF, TK_ELSE, TK_WHILE, TK_FOR, TK_DO, TK_RETURN, TK_HALT,
    TK_ASM, TK_FPU,
    /* Instrucciones ensamblador NB-64 — 1 byte */
    TK_NOP, TK_HALT_ASM, TK_RET, TK_IRET, TK_FPU_OP,
    /* Instrucciones 2 bytes */
    TK_MOV, TK_XCHG, TK_PUSH, TK_POP,
    TK_ADD, TK_SUB, TK_MUL, TK_DIV, TK_ADC, TK_SBB,
    TK_INC, TK_DEC, TK_NEG,
    TK_AND_OP, TK_XOR_OP, TK_XORA, TK_NOT_OP,
    TK_CMP, TK_TEST,
    TK_SHL, TK_SHR, TK_ROL, TK_ROR,
    /* Instrucciones 4 bytes */
    TK_MOVI, TK_ADDI,
    /* Instrucciones 8 bytes */
    TK_JMP, TK_JZ, TK_JNZ, TK_JC, TK_JNC,
    TK_CALL, TK_LOAD, TK_STORE, TK_LEA,
    /* Registros */
    TK_REG, TK_PC, TK_SP,
    /* Literales */
    TK_INT_LIT, TK_FLOAT_LIT, TK_BIN_LIT, TK_HEX_LIT, TK_BIN_RAW,
    TK_STRING, TK_CHAR_LIT,
    /* Identificadores y etiquetas */
    TK_ID, TK_LABEL,
    /* Directivas de preprocesador */
    TK_INCLUDE, TK_DEFINE,
    /* Operadores aritmeticos */
    TK_PLUS, TK_MINUS, TK_STAR, TK_SLASH, TK_MOD,
    /* Operadores de asignacion */
    TK_ASSIGN, TK_PLUS_ASSIGN, TK_MINUS_ASSIGN,
    TK_STAR_ASSIGN, TK_SLASH_ASSIGN,
    /* Operadores relacionales */
    TK_EQ, TK_NEQ, TK_LT, TK_GT, TK_LE, TK_GE,
    /* Operadores logicos */
    TK_AND, TK_OR, TK_NOT,
    /* Operadores de bits */
    TK_BITAND, TK_BITOR, TK_BITXOR, TK_BITNOT, TK_LSHIFT, TK_RSHIFT,
    /* Delimitadores */
    TK_LPAREN, TK_RPAREN, TK_LBRACE, TK_RBRACE,
    TK_LBRACK, TK_RBRACK,
    TK_SEMI, TK_COMMA, TK_DOT, TK_COLON,
    /* Error */
    TK_ERROR
} TokenType;

static const char *token_names[] = {
    "EOF",
    "INT","FLOAT","VOID","ARRAY","MATRIX","STRUCT",
    "IF","ELSE","WHILE","FOR","DO","RETURN","HALT","ASM","FPU",
    "NOP","HALT_ASM","RET","IRET","FPU_OP",
    "MOV","XCHG","PUSH","POP",
    "ADD","SUB","MUL","DIV","ADC","SBB",
    "INC","DEC","NEG",
    "AND_OP","XOR_OP","XORA","NOT_OP",
    "CMP","TEST",
    "SHL","SHR","ROL","ROR",
    "MOVI","ADDI",
    "JMP","JZ","JNZ","JC","JNC",
    "CALL","LOAD","STORE","LEA",
    "REG","PC","SP",
    "INT_LIT","FLOAT_LIT","BIN_LIT","HEX_LIT","BIN_RAW",
    "STRING","CHAR_LIT",
    "ID","LABEL",
    "INCLUDE","DEFINE",
    "PLUS","MINUS","STAR","SLASH","MOD",
    "ASSIGN","PLUS_ASSIGN","MINUS_ASSIGN","STAR_ASSIGN","SLASH_ASSIGN",
    "EQ","NEQ","LT","GT","LE","GE",
    "AND","OR","NOT",
    "BITAND","BITOR","BITXOR","BITNOT","LSHIFT","RSHIFT",
    "LPAREN","RPAREN","LBRACE","RBRACE","LBRACK","RBRACK",
    "SEMI","COMMA","DOT","COLON",
    "ERROR"
};

int linea = 1;
int num_tokens = 0;

void imprimir_token(TokenType tipo, const char *lexema, const char *categoria) {
    num_tokens++;
    printf("%-5d | %-20s | %-24s | %s\n",
           linea, token_names[tipo], categoria, lexema);
}
%}

%option noyywrap

DIGIT       [0-9]
LETTER      [a-zA-Z_]
ALNUM       [a-zA-Z0-9_]
WS          [ \t\r]+
BIN         0b[01]+
HEX         0x[0-9A-Fa-f]+
FLOAT       {DIGIT}+"."{DIGIT}+([eE][+-]?{DIGIT}+)?
INT         {DIGIT}+
STRING      \"([^\\\"\n]|\\.)*\"
CHARLIT     \'([^\\\'\n]|\\.)\'
BIN_RAW     [01][01][01][01][01][01][01][01]
COMMENT     "#"[^\n]*
COMMENT2    \/\/[^\n]*
ID          {LETTER}{ALNUM}*
LABEL       {LETTER}{ALNUM}*":"

%%

{WS}            { /* ignorar espacios */ }
"\n"            { linea++; }
"#include"      { imprimir_token(TK_INCLUDE, yytext, "DIRECTIVA"); }
"#define"       { imprimir_token(TK_DEFINE,  yytext, "DIRECTIVA"); }
{COMMENT}       { /* ignorar comentarios # */ }
{COMMENT2}      { /* ignorar comentarios // */ }

"int"       { imprimir_token(TK_INT,     yytext, "PALABRA_RESERVADA"); }
"float"     { imprimir_token(TK_FLOAT,   yytext, "PALABRA_RESERVADA"); }
"void"      { imprimir_token(TK_VOID,    yytext, "PALABRA_RESERVADA"); }
"array"     { imprimir_token(TK_ARRAY,   yytext, "PALABRA_RESERVADA"); }
"matrix"    { imprimir_token(TK_MATRIX,  yytext, "PALABRA_RESERVADA"); }
"struct"    { imprimir_token(TK_STRUCT,  yytext, "PALABRA_RESERVADA"); }
"if"        { imprimir_token(TK_IF,      yytext, "PALABRA_RESERVADA"); }
"else"      { imprimir_token(TK_ELSE,    yytext, "PALABRA_RESERVADA"); }
"while"     { imprimir_token(TK_WHILE,   yytext, "PALABRA_RESERVADA"); }
"for"       { imprimir_token(TK_FOR,     yytext, "PALABRA_RESERVADA"); }
"do"        { imprimir_token(TK_DO,      yytext, "PALABRA_RESERVADA"); }
"return"    { imprimir_token(TK_RETURN,  yytext, "PALABRA_RESERVADA"); }
"halt"      { imprimir_token(TK_HALT,    yytext, "PALABRA_RESERVADA"); }
"asm"       { imprimir_token(TK_ASM,     yytext, "PALABRA_RESERVADA"); }
"fpu"       { imprimir_token(TK_FPU,     yytext, "PALABRA_RESERVADA"); }

"NOP"       { imprimir_token(TK_NOP,     yytext, "INSTRUCCION_1B"); }
"HALT"      { imprimir_token(TK_HALT_ASM,yytext, "INSTRUCCION_1B"); }
"RET"       { imprimir_token(TK_RET,     yytext, "INSTRUCCION_1B"); }
"IRET"      { imprimir_token(TK_IRET,    yytext, "INSTRUCCION_1B"); }
"FPU_OP"    { imprimir_token(TK_FPU_OP,  yytext, "INSTRUCCION_1B"); }

"XCHG"      { imprimir_token(TK_XCHG,   yytext, "INSTRUCCION_2B"); }
"PUSH"      { imprimir_token(TK_PUSH,   yytext, "INSTRUCCION_2B"); }
"POP"       { imprimir_token(TK_POP,    yytext, "INSTRUCCION_2B"); }
"ADD"       { imprimir_token(TK_ADD,    yytext, "INSTRUCCION_2B"); }
"SUB"       { imprimir_token(TK_SUB,    yytext, "INSTRUCCION_2B"); }
"MUL"       { imprimir_token(TK_MUL,    yytext, "INSTRUCCION_2B"); }
"DIV"       { imprimir_token(TK_DIV,    yytext, "INSTRUCCION_2B"); }
"ADC"       { imprimir_token(TK_ADC,    yytext, "INSTRUCCION_2B"); }
"SBB"       { imprimir_token(TK_SBB,    yytext, "INSTRUCCION_2B"); }
"INC"       { imprimir_token(TK_INC,    yytext, "INSTRUCCION_2B"); }
"DEC"       { imprimir_token(TK_DEC,    yytext, "INSTRUCCION_2B"); }
"NEG"       { imprimir_token(TK_NEG,    yytext, "INSTRUCCION_2B"); }
"AND"       { imprimir_token(TK_AND_OP, yytext, "INSTRUCCION_2B"); }
"XOR"       { imprimir_token(TK_XOR_OP, yytext, "INSTRUCCION_2B"); }
"XORA"      { imprimir_token(TK_XORA,   yytext, "INSTRUCCION_2B"); }
"NOT"       { imprimir_token(TK_NOT_OP, yytext, "INSTRUCCION_2B"); }
"CMP"       { imprimir_token(TK_CMP,    yytext, "INSTRUCCION_2B"); }
"TEST"      { imprimir_token(TK_TEST,   yytext, "INSTRUCCION_2B"); }
"SHL"       { imprimir_token(TK_SHL,    yytext, "INSTRUCCION_2B"); }
"SHR"       { imprimir_token(TK_SHR,    yytext, "INSTRUCCION_2B"); }
"ROL"       { imprimir_token(TK_ROL,    yytext, "INSTRUCCION_2B"); }
"ROR"       { imprimir_token(TK_ROR,    yytext, "INSTRUCCION_2B"); }
"MOV"       { imprimir_token(TK_MOV,    yytext, "INSTRUCCION_2B"); }

"MOVI"      { imprimir_token(TK_MOVI,   yytext, "INSTRUCCION_4B"); }
"ADDI"      { imprimir_token(TK_ADDI,   yytext, "INSTRUCCION_4B"); }

"JMP"       { imprimir_token(TK_JMP,    yytext, "INSTRUCCION_8B"); }
"JZ"        { imprimir_token(TK_JZ,     yytext, "INSTRUCCION_8B"); }
"JNZ"       { imprimir_token(TK_JNZ,   yytext, "INSTRUCCION_8B"); }
"JC"        { imprimir_token(TK_JC,     yytext, "INSTRUCCION_8B"); }
"JNC"       { imprimir_token(TK_JNC,    yytext, "INSTRUCCION_8B"); }
"CALL"      { imprimir_token(TK_CALL,   yytext, "INSTRUCCION_8B"); }
"LOAD"      { imprimir_token(TK_LOAD,   yytext, "INSTRUCCION_8B"); }
"STORE"     { imprimir_token(TK_STORE,  yytext, "INSTRUCCION_8B"); }
"LEA"       { imprimir_token(TK_LEA,    yytext, "INSTRUCCION_8B"); }

"R"[0-7]    { imprimir_token(TK_REG,  yytext, "REGISTRO"); }
"PC"        { imprimir_token(TK_PC,   yytext, "REGISTRO"); }
"SP"        { imprimir_token(TK_SP,   yytext, "REGISTRO"); }

{BIN}       { imprimir_token(TK_BIN_LIT,   yytext, "LITERAL_BINARIO"); }
{HEX}       { imprimir_token(TK_HEX_LIT,   yytext, "LITERAL_HEX"); }
{FLOAT}     { imprimir_token(TK_FLOAT_LIT, yytext, "LITERAL_REAL"); }
{INT}       { imprimir_token(TK_INT_LIT,   yytext, "LITERAL_ENTERO"); }
{STRING}    { imprimir_token(TK_STRING,    yytext, "LITERAL_CADENA"); }
{CHARLIT}   { imprimir_token(TK_CHAR_LIT,  yytext, "LITERAL_CARACTER"); }
{LABEL}     { imprimir_token(TK_LABEL,     yytext, "ETIQUETA"); }

"+="        { imprimir_token(TK_PLUS_ASSIGN,  yytext, "OP_ASIGNACION"); }
"-="        { imprimir_token(TK_MINUS_ASSIGN, yytext, "OP_ASIGNACION"); }
"*="        { imprimir_token(TK_STAR_ASSIGN,  yytext, "OP_ASIGNACION"); }
"/="        { imprimir_token(TK_SLASH_ASSIGN, yytext, "OP_ASIGNACION"); }
"=="        { imprimir_token(TK_EQ,  yytext, "OP_RELACIONAL"); }
"!="        { imprimir_token(TK_NEQ, yytext, "OP_RELACIONAL"); }
"<="        { imprimir_token(TK_LE,  yytext, "OP_RELACIONAL"); }
">="        { imprimir_token(TK_GE,  yytext, "OP_RELACIONAL"); }
"&&"        { imprimir_token(TK_AND, yytext, "OP_LOGICO"); }
"||"        { imprimir_token(TK_OR,  yytext, "OP_LOGICO"); }
"<<"        { imprimir_token(TK_LSHIFT, yytext, "OP_BITS"); }
">>"        { imprimir_token(TK_RSHIFT, yytext, "OP_BITS"); }
"+"         { imprimir_token(TK_PLUS,   yytext, "OP_ARITMETICO"); }
"-"         { imprimir_token(TK_MINUS,  yytext, "OP_ARITMETICO"); }
"*"         { imprimir_token(TK_STAR,   yytext, "OP_ARITMETICO"); }
"/"         { imprimir_token(TK_SLASH,  yytext, "OP_ARITMETICO"); }
"%"         { imprimir_token(TK_MOD,    yytext, "OP_ARITMETICO"); }
"="         { imprimir_token(TK_ASSIGN, yytext, "OP_ASIGNACION"); }
"<"         { imprimir_token(TK_LT,     yytext, "OP_RELACIONAL"); }
">"         { imprimir_token(TK_GT,     yytext, "OP_RELACIONAL"); }
"!"         { imprimir_token(TK_NOT,    yytext, "OP_LOGICO"); }
"&"         { imprimir_token(TK_BITAND, yytext, "OP_BITS"); }
"|"         { imprimir_token(TK_BITOR,  yytext, "OP_BITS"); }
"^"         { imprimir_token(TK_BITXOR, yytext, "OP_BITS"); }
"~"         { imprimir_token(TK_BITNOT, yytext, "OP_BITS"); }
"("         { imprimir_token(TK_LPAREN, yytext, "DELIMITADOR"); }
")"         { imprimir_token(TK_RPAREN, yytext, "DELIMITADOR"); }
"{"         { imprimir_token(TK_LBRACE, yytext, "DELIMITADOR"); }
"}"         { imprimir_token(TK_RBRACE, yytext, "DELIMITADOR"); }
"["         { imprimir_token(TK_LBRACK, yytext, "DELIMITADOR"); }
"]"         { imprimir_token(TK_RBRACK, yytext, "DELIMITADOR"); }
";"         { imprimir_token(TK_SEMI,   yytext, "DELIMITADOR"); }
","         { imprimir_token(TK_COMMA,  yytext, "DELIMITADOR"); }
"."         { imprimir_token(TK_DOT,    yytext, "DELIMITADOR"); }
":"         { imprimir_token(TK_COLON,  yytext, "DELIMITADOR"); }

{ID}        { imprimir_token(TK_ID,     yytext, "IDENTIFICADOR"); }
.           { fprintf(stderr, "[LEXICO] Error linea %d: caracter no reconocido '%s'\n",
                      linea, yytext);
              imprimir_token(TK_ERROR, yytext, "ERROR"); }

%%

int main(int argc, char *argv[]) {
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
        if (!yyin) {
            fprintf(stderr, "Error: no se puede abrir '%s'\n", argv[1]);
            return 1;
        }
    }
    printf("%-5s | %-20s | %-24s | %s\n",
           "LINEA", "TOKEN", "CATEGORIA", "LEXEMA");
    printf("------|---------------------|--------------------------|----------\n");
    yylex();
    printf("------|---------------------|--------------------------|----------\n");
    printf("Total tokens reconocidos: %d\n", num_tokens);
    if (argc == 2) fclose(yyin);
    return 0;
}
