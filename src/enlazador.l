%{
/*
 * enlazador.l
 * Enlazador-Cargador NB-64
 * Une multiples archivos .obj y resuelve referencias externas
 * Uso: ./enlazador modulo_a.obj modulo_b.obj -o salida.bin
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_BYTES    4096
#define MAX_SYMBOLS   256
#define MAX_PATCHES   256

/* ── Imagen de memoria final ── */
char imagen[MAX_BYTES][9];
int  total_bytes = 0;

/* ── Tabla de simbolos globales ── */
typedef struct {
    char nombre[64];
    int  addr;
    int  es_global;
} Symbol;

Symbol sym_table[MAX_SYMBOLS];
int    num_symbols = 0;

/* ── Tabla de parches (referencias externas a resolver) ── */
typedef struct {
    char nombre[64];   /* nombre del simbolo externo */
    int  addr_parche;  /* direccion en imagen donde parchear */
    int  tipo;         /* 0=DIR48 en instruccion de 8 bytes  */
} Patch;

Patch patches[MAX_PATCHES];
int   num_patches = 0;

/* ── Funciones ── */
void cargar_obj(const char *filename);
void agregar_simbolo(const char *nombre, int addr, int es_global);
int  buscar_simbolo(const char *nombre);
void agregar_parche(const char *nombre, int addr_parche);
void resolver_parches();
void emitir_imagen(const char *filename);
void parchear_dir48(int addr_parche, int dir);

%}

%option noyywrap

%%
.|\n { }
%%

/* ════════════════════════════════════
   CARGA DE ARCHIVO .OBJ
   ════════════════════════════════════ */

void cargar_obj(const char *filename) {
    FILE *f = fopen(filename, "r");
    if (!f) {
        fprintf(stderr, "[ENLAZADOR] Error: no se puede abrir '%s'\n",
                filename);
        exit(1);
    }

    fprintf(stderr, "[ENLAZADOR] Cargando: %s (base=%d)\n",
            filename, total_bytes);

    int base = total_bytes;
    char linea[256];

    while (fgets(linea, sizeof(linea), f)) {
        /* Quitar \r y \n */
        char *cr = strchr(linea, '\r');
        if (cr) *cr = '\0';
        char *nl = strchr(linea, '\n');
        if (nl) *nl = '\0';

        /* Saltar lineas vacias */
        if (strlen(linea) == 0) continue;

        /* Directiva GLOBAL nombre addr */
        if (strncmp(linea, "GLOBAL ", 7) == 0) {
            char nombre[64];
            int  addr;
            sscanf(linea + 7, "%s %d", nombre, &addr);
            agregar_simbolo(nombre, base + addr, 1);
            fprintf(stderr, "[ENLAZADOR] Simbolo global '%s' → addr %d\n",
                    nombre, base + addr);
            continue;
        }

        /* Directiva EXTERN nombre addr_parche */
        if (strncmp(linea, "EXTERN ", 7) == 0) {
            char nombre[64];
            int  addr_parche;
            sscanf(linea + 7, "%s %d", nombre, &addr_parche);
            agregar_parche(nombre, base + addr_parche);
            fprintf(stderr,
                    "[ENLAZADOR] Parche pendiente '%s' en addr %d\n",
                    nombre, base + addr_parche);
            continue;
        }

        /* Linea binaria de 8 bits */
        if (strlen(linea) == 8) {
            int valido = 1;
            for (int i = 0; i < 8; i++)
                if (linea[i] != '0' && linea[i] != '1')
                    valido = 0;
            if (valido) {
                if (total_bytes >= MAX_BYTES) {
                    fprintf(stderr,
                            "[ENLAZADOR] Error: imagen llena\n");
                    exit(1);
                }
                strncpy(imagen[total_bytes], linea, 8);
                imagen[total_bytes][8] = '\0';
                total_bytes++;
            }
        }
    }

    fclose(f);
    fprintf(stderr, "[ENLAZADOR] '%s' cargado: %d bytes\n",
            filename, total_bytes - base);
}

/* ════════════════════════════════════
   TABLA DE SIMBOLOS
   ════════════════════════════════════ */

void agregar_simbolo(const char *nombre, int addr, int es_global) {
    for (int i = 0; i < num_symbols; i++) {
        if (strcmp(sym_table[i].nombre, nombre) == 0) {
            sym_table[i].addr      = addr;
            sym_table[i].es_global = es_global;
            return;
        }
    }
    strncpy(sym_table[num_symbols].nombre, nombre, 63);
    sym_table[num_symbols].addr      = addr;
    sym_table[num_symbols].es_global = es_global;
    num_symbols++;
}

int buscar_simbolo(const char *nombre) {
    for (int i = 0; i < num_symbols; i++)
        if (strcmp(sym_table[i].nombre, nombre) == 0)
            return sym_table[i].addr;
    return -1;
}

/* ════════════════════════════════════
   TABLA DE PARCHES
   ════════════════════════════════════ */

void agregar_parche(const char *nombre, int addr_parche) {
    strncpy(patches[num_patches].nombre, nombre, 63);
    patches[num_patches].addr_parche = addr_parche;
    patches[num_patches].tipo        = 0;
    num_patches++;
}

/* Escribe una direccion de 48 bits en la imagen
   a partir de addr_parche, respetando el opcode
   en los primeros 7 bits del byte inicial */
void parchear_dir48(int addr_parche, int dir) {
    /* Los 8 bytes de la instruccion DIR:
       [opcode7][dir48][pad9]
       El opcode esta en bits 7-1 del byte 0
       Los bits de dir empiezan en bit 0 del byte 0 */

    /* Construir string de 64 bits de la instruccion completa */
    char instr[65];
    /* Leer los 8 bytes actuales */
    for (int i = 0; i < 8; i++)
        for (int b = 0; b < 8; b++)
            instr[i*8+b] = imagen[addr_parche+i][b];
    instr[64] = '\0';

    /* Reemplazar bits 7..56 con la direccion (48 bits) */
    for (int i = 47; i >= 0; i--) {
        int bit_pos = 7 + (47 - i);
        instr[bit_pos] = ((dir >> i) & 1) ? '1' : '0';
    }

    /* Escribir los 8 bytes de vuelta a la imagen */
    for (int i = 0; i < 8; i++) {
        strncpy(imagen[addr_parche+i], instr + i*8, 8);
        imagen[addr_parche+i][8] = '\0';
    }
}

/* ════════════════════════════════════
   RESOLVER PARCHES
   ════════════════════════════════════ */

void resolver_parches() {
    fprintf(stderr, "[ENLAZADOR] Resolviendo %d parche(s)...\n",
            num_patches);

    for (int i = 0; i < num_patches; i++) {
        int addr = buscar_simbolo(patches[i].nombre);
        if (addr == -1) {
            fprintf(stderr,
                "[ENLAZADOR] Error: simbolo '%s' no resuelto\n",
                patches[i].nombre);
            exit(1);
        }
        fprintf(stderr,
            "[ENLAZADOR] Parcheando '%s': addr %d → pos %d\n",
            patches[i].nombre, addr, patches[i].addr_parche);
        parchear_dir48(patches[i].addr_parche, addr);
    }
}

/* ════════════════════════════════════
   EMITIR IMAGEN FINAL
   ════════════════════════════════════ */

void emitir_imagen(const char *filename) {
    FILE *f = stdout;
    if (filename) {
        f = fopen(filename, "w");
        if (!f) {
            fprintf(stderr,
                "[ENLAZADOR] Error: no se puede crear '%s'\n",
                filename);
            exit(1);
        }
    }

    for (int i = 0; i < total_bytes; i++)
        fprintf(f, "%s\n", imagen[i]);

    if (filename) fclose(f);

    fprintf(stderr,
        "[ENLAZADOR] Imagen final: %d bytes\n", total_bytes);
}

/* ════════════════════════════════════
   MAIN
   ════════════════════════════════════ */

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr,
            "Uso: %s archivo1.obj [archivo2.obj ...] [-o salida.bin]\n",
            argv[0]);
        return 1;
    }

    char *output_file = NULL;

    /* Procesar argumentos */
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-o") == 0) {
            if (i + 1 < argc)
                output_file = argv[++i];
        } else {
            cargar_obj(argv[i]);
        }
    }

    /* Resolver referencias externas */
    resolver_parches();

    /* Emitir imagen final */
    emitir_imagen(output_file);

    return 0;
}