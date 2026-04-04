%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_MACROS   256
#define MAX_NOMBRE    64
#define MAX_VALOR    256
#define MAX_INCLUDES  32

typedef struct {
    char nombre[MAX_NOMBRE];
    char valor[MAX_VALOR];
} Macro;

Macro tabla_macros[MAX_MACROS];
int   num_macros = 0;

char archivos_incluidos[MAX_INCLUDES][256];
int  num_includes = 0;

void        agregar_macro(const char *nombre, const char *valor);
const char *buscar_macro(const char *nombre);
void        procesar_include(const char *filename);
int         ya_incluido(const char *filename);
%}

%option noyywrap

%%

"#define"[ \t]+[a-zA-Z_][a-zA-Z0-9_]*[ \t]+[^\n]* {
    char nombre[MAX_NOMBRE];
    char valor[MAX_VALOR];
    char *p = yytext + 7;
    while (*p == ' ' || *p == '\t') p++;
    int i = 0;
    while (*p && *p != ' ' && *p != '\t' && i < MAX_NOMBRE-1)
        nombre[i++] = *p++;
    nombre[i] = '\0';
    while (*p == ' ' || *p == '\t') p++;
    i = 0;
    while (*p && *p != '\n' && i < MAX_VALOR-1)
        valor[i++] = *p++;
    valor[i] = '\0';
    agregar_macro(nombre, valor);
    /* no emitir nada */
}

"#include"[ \t]+\"[^\"]+\" {
    char filename[256];
    char *inicio = strchr(yytext, '"') + 1;
    char *fin    = strrchr(yytext, '"');
    int   len    = fin - inicio;
    strncpy(filename, inicio, len);
    filename[len] = '\0';
    procesar_include(filename);
}

"#"[^\n]* {
    /* comentario # — ignorar toda la linea */
}

[a-zA-Z_][a-zA-Z0-9_]* {
    const char *val = buscar_macro(yytext);
    if (val)
        fputs(val, stdout);
    else
        fputs(yytext, stdout);
}

[^\n] {
    fputc(yytext[0], stdout);
}

\n {
    fputc('\n', stdout);
}

%%

void agregar_macro(const char *nombre, const char *valor) {
    for (int i = 0; i < num_macros; i++) {
        if (strcmp(tabla_macros[i].nombre, nombre) == 0) {
            strncpy(tabla_macros[i].valor, valor, MAX_VALOR-1);
            fprintf(stderr, "[PREPROCESADOR] Redefinida: %s = %s\n", nombre, valor);
            return;
        }
    }
    if (num_macros >= MAX_MACROS) {
        fprintf(stderr, "[PREPROCESADOR] Error: tabla llena\n");
        exit(1);
    }
    strncpy(tabla_macros[num_macros].nombre, nombre, MAX_NOMBRE-1);
    strncpy(tabla_macros[num_macros].valor,  valor,  MAX_VALOR-1);
    fprintf(stderr, "[PREPROCESADOR] Macro: %s = %s\n", nombre, valor);
    num_macros++;
}

const char *buscar_macro(const char *nombre) {
    for (int i = 0; i < num_macros; i++)
        if (strcmp(tabla_macros[i].nombre, nombre) == 0)
            return tabla_macros[i].valor;
    return NULL;
}

int ya_incluido(const char *filename) {
    for (int i = 0; i < num_includes; i++)
        if (strcmp(archivos_incluidos[i], filename) == 0)
            return 1;
    return 0;
}

void procesar_include(const char *filename) {
    if (ya_incluido(filename)) {
        fprintf(stderr, "[PREPROCESADOR] '%s' ya incluido\n", filename);
        return;
    }
    strncpy(archivos_incluidos[num_includes++], filename, 255);
    FILE *f = fopen(filename, "r");
    if (!f) {
        fprintf(stderr, "[PREPROCESADOR] Error: no se puede abrir '%s'\n", filename);
        exit(1);
    }
    fprintf(stderr, "[PREPROCESADOR] Incluyendo: %s\n", filename);
    int c;
    while ((c = fgetc(f)) != EOF)
        putchar(c);
    fclose(f);
}

int main(int argc, char *argv[]) {
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
        if (!yyin) {
            fprintf(stderr, "Error: no se puede abrir '%s'\n", argv[1]);
            return 1;
        }
    }
    yylex();
    return 0;
}