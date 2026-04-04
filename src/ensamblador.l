%{
/*
 * ensamblador.l
 * Ensamblador NB-64: convierte mnemonics a binario
 * Dos pasadas:
 *   Pasada 1: recolectar etiquetas y calcular direcciones
 *   Pasada 2: generar binario
 * Uso: ./ensamblador programa.asm
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

/* ── Tabla de etiquetas ── */
#define MAX_LABELS  256
#define MAX_OUTPUT  4096

typedef struct {
    char nombre[64];
    int  addr;
} Label;

Label labels[MAX_LABELS];
int   num_labels  = 0;
int   current_addr = 0;
int   pasada       = 1;

/* ── Buffer de salida ── */
char output[MAX_OUTPUT][9];  /* cada línea = 8 bits + null */
int  num_output = 0;

/* ── Funciones auxiliares ── */
void        agregar_label(const char *nombre, int addr);
int         buscar_label(const char *nombre);
void        emitir_byte(const char *bits);
void        ensamblar_linea(const char *linea);
int         reg_num(const char *r);
void        emit_movi(int ra, int imm8);
void        emit_addi(int ra, int imm8);
void        emit_rr(const char *opcode, int ra, int rb);
void        emit_r(const char *opcode, int ra);
void        emit_dir(const char *opcode7, int dir);
void        emit_r_dir(const char *opcode7, int ra, int dir);
void        int_to_bin8(int v, char *out);
void        int_to_bin48(long long v, char *out);

%}

%option noyywrap

%%
.|\n  { /* El lexer solo se usa para disparar main */ }
%%

/* ════════════════════════════════════════
   UTILIDADES DE CODIFICACIÓN
   ════════════════════════════════════════ */

/* Convierte entero a binario de 8 bits */
void int_to_bin8(int v, char *out) {
    for (int i = 7; i >= 0; i--)
        out[7-i] = ((v >> i) & 1) ? '1' : '0';
    out[8] = '\0';
}

/* Convierte entero a binario de 48 bits */
void int_to_bin48(long long v, char *out) {
    for (int i = 47; i >= 0; i--)
        out[47-i] = ((v >> i) & 1) ? '1' : '0';
    out[48] = '\0';
}

/* Número de registro: "R0"→0, "R1"→1, ... */
int reg_num(const char *r) {
    if (r[0] == 'R' || r[0] == 'r')
        return atoi(r + 1);
    return 0;
}

/* Emitir un byte al buffer de salida */
void emitir_byte(const char *bits) {
    if (num_output >= MAX_OUTPUT) {
        fprintf(stderr, "Error: buffer de salida lleno\n");
        exit(1);
    }
    strncpy(output[num_output++], bits, 8);
    output[num_output-1][8] = '\0';
}

/* ════════════════════════════════════════
   TABLA DE ETIQUETAS
   ════════════════════════════════════════ */

void agregar_label(const char *nombre, int addr) {
    for (int i = 0; i < num_labels; i++) {
        if (strcmp(labels[i].nombre, nombre) == 0) {
            labels[i].addr = addr;
            return;
        }
    }
    strncpy(labels[num_labels].nombre, nombre, 63);
    labels[num_labels].addr = addr;
    num_labels++;
    fprintf(stderr, "[ENSAMBLADOR] Label '%s' → addr %d\n", nombre, addr);
}

int buscar_label(const char *nombre) {
    for (int i = 0; i < num_labels; i++)
        if (strcmp(labels[i].nombre, nombre) == 0)
            return labels[i].addr;
    fprintf(stderr, "[ENSAMBLADOR] Error: label '%s' no definida\n", nombre);
    return 0;
}

/* ════════════════════════════════════════
   EMISORES DE INSTRUCCIONES
   ════════════════════════════════════════ */

/* MOVI Ra, Imm8 — 4 bytes
   Formato: 1000000 [Ra:4b] [Imm8:8b] [pad:13b] */
void emit_movi(int ra, int imm8) {
    /* Formato: 1000000 [Ra:4b] [Imm8:8b] [pad:13b] = 32 bits
       Ejemplo MOVI R0, 5:
         1000000 0000 00000101 0000000000000
         Byte0=10000000 Byte1=00000000 Byte2=10100000 Byte3=00000000 */
    char total[33];
    char ra_bin[5];
    char imm8_bin[9];
    char pad[14];

    /* opcode fijo */
    strcpy(total, "1000000");

    /* Ra en 4 bits */
    for (int i = 3; i >= 0; i--)
        ra_bin[3-i] = ((ra >> i) & 1) ? '1' : '0';
    ra_bin[4] = '\0';
    strcat(total, ra_bin);

    /* Imm8 en 8 bits */
    for (int i = 7; i >= 0; i--)
        imm8_bin[7-i] = ((imm8 >> i) & 1) ? '1' : '0';
    imm8_bin[8] = '\0';
    strcat(total, imm8_bin);

    /* pad 13 bits */
    strcpy(pad, "0000000000000");
    strcat(total, pad);

    /* Emitir 4 bytes */
    char byte[9];
    for (int i = 0; i < 4; i++) {
        strncpy(byte, total + i*8, 8);
        byte[8] = '\0';
        emitir_byte(byte);
    }
}

/* ADDI Ra, Imm8 — 4 bytes
   Formato: 1000001 [Ra:4b] [Imm8:8b] [pad:13b] */
void emit_addi(int ra, int imm8) {
    /* Formato: 1000001 [Ra:4b] [Imm8:8b] [pad:13b] */
    char total[33];
    char ra_bin[5];
    char imm8_bin[9];

    strcpy(total, "1000001");

    for (int i = 3; i >= 0; i--)
        ra_bin[3-i] = ((ra >> i) & 1) ? '1' : '0';
    ra_bin[4] = '\0';
    strcat(total, ra_bin);

    for (int i = 7; i >= 0; i--)
        imm8_bin[7-i] = ((imm8 >> i) & 1) ? '1' : '0';
    imm8_bin[8] = '\0';
    strcat(total, imm8_bin);

    strcat(total, "0000000000000");

    char byte[9];
    for (int i = 0; i < 4; i++) {
        strncpy(byte, total + i*8, 8);
        byte[8] = '\0';
        emitir_byte(byte);
    }
}

/* Instrucciones RR — 2 bytes
   Formato: [opcode7] [Ra:4b] [Rb:4b] [pad:1b] */
void emit_rr(const char *opcode7, int ra, int rb) {
    char b0[9], b1[9];
    /* Byte 0: opcode7 + bit alto de Ra */
    unsigned int word = 0;
    /* Construir 16 bits: opcode7[6:0] Ra[3:0] Rb[3:0] pad[0] */
    unsigned int hi = 0;
    /* opcode7 es string de 7 chars '0'/'1' */
    for (int i = 0; i < 7; i++)
        hi = (hi << 1) | (opcode7[i] == '1' ? 1 : 0);
    unsigned int val16 = (hi << 9) | ((ra & 0xF) << 5) |
                         ((rb & 0xF) << 1) | 0;
    int_to_bin8((val16 >> 8) & 0xFF, b0);
    int_to_bin8((val16 >> 0) & 0xFF, b1);
    emitir_byte(b0);
    emitir_byte(b1);
}

/* Instrucciones R — 2 bytes (Rb=0, pad=0) */
void emit_r(const char *opcode7, int ra) {
    emit_rr(opcode7, ra, 0);
}

/* Instrucciones DIR — 8 bytes
   Formato: [opcode7] [Dir:48b] [pad:9b] */
void emit_dir(const char *opcode7, int dir) {
    char bits[65];
    unsigned int hi = 0;
    for (int i = 0; i < 7; i++)
        hi = (hi << 1) | (opcode7[i] == '1' ? 1 : 0);

    /* 64 bits: opcode7 + dir48 + pad9 */
    char b48[49];
    int_to_bin48((long long)dir, b48);

    /* Construir los 8 bytes */
    char full[65];
    full[0] = '\0';
    /* opcode7 */
    strncat(full, opcode7, 7);
    /* dir 48 bits */
    strncat(full, b48, 48);
    /* pad 9 bits */
    strncat(full, "000000000", 10);

    /* Emitir 8 bytes */
    char byte[9];
    for (int i = 0; i < 8; i++) {
        strncpy(byte, full + i*8, 8);
        byte[8] = '\0';
        emitir_byte(byte);
    }
}

/* Instrucciones R_DIR — 8 bytes
   Formato: [opcode7] [Ra:4b] [Dir:48b] [pad:5b] */
void emit_r_dir(const char *opcode7, int ra, int dir) {
    char b48[49];
    int_to_bin48((long long)dir, b48);

    char ra_bin[5];
    for (int i = 3; i >= 0; i--)
        ra_bin[3-i] = ((ra >> i) & 1) ? '1' : '0';
    ra_bin[4] = '\0';

    char full[65];
    full[0] = '\0';
    strncat(full, opcode7, 7);
    strncat(full, ra_bin, 4);
    strncat(full, b48, 48);
    strncat(full, "00000", 6);

    char byte[9];
    for (int i = 0; i < 8; i++) {
        strncpy(byte, full + i*8, 8);
        byte[8] = '\0';
        emitir_byte(byte);
    }
}

/* ════════════════════════════════════════
   ENSAMBLADO DE UNA LÍNEA
   ════════════════════════════════════════ */

void ensamblar_linea(const char *linea) {
    char buf[256];
    strncpy(buf, linea, 255);

    /* Quitar comentario # */
    char *com = strchr(buf, '#');
    if (com) *com = '\0';

    /* Quitar \r y \n */
    char *cr = strchr(buf, '\r');
    if (cr) *cr = '\0';
    char *nl = strchr(buf, '\n');
    if (nl) *nl = '\0';

    /* Saltar espacios iniciales */
    char *p = buf;
    while (*p == ' ' || *p == '\t') p++;

    /* Línea vacía */
    if (*p == '\0') return;

    /* Detectar etiqueta: termina en ':' */
    char *colon = strchr(p, ':');
    if (colon && (colon[1] == '\0' || colon[1] == ' ' ||
                  colon[1] == '\t' || colon[1] == '\r')) {
        *colon = '\0';
        if (pasada == 1)
            agregar_label(p, current_addr);
        return;
    }

    /* Leer mnemónico */
    char mnem[32];
    int i = 0;
    while (*p && *p != ' ' && *p != '\t' && i < 31)
        mnem[i++] = toupper(*p++);
    mnem[i] = '\0';

    /* Saltar espacios */
    while (*p == ' ' || *p == '\t') p++;

    /* ── Directivas de enlace ── */
    if (strcmp(mnem, "GLOBAL") == 0) {
        char nombre[64];
        sscanf(p, "%s", nombre);
        if (pasada == 2)
            printf("GLOBAL %s %d\n", nombre, current_addr);
        return;
    }
    if (strcmp(mnem, "EXTERN") == 0) {
        char nombre[64];
        sscanf(p, "%s", nombre);
        if (pasada == 2) {
            printf("EXTERN %s %d\n", nombre, current_addr);
            for (int j = 0; j < 8; j++)
                emitir_byte("00000000");
        }
        current_addr += 8;
        return;
    }

    /* ── Instrucciones de 1 byte ── */
    if (strcmp(mnem, "NOP")    == 0) {
        current_addr += 1;
        if (pasada == 2) emitir_byte("00000000");
        return;
    }
    if (strcmp(mnem, "HALT")   == 0) {
        current_addr += 1;
        if (pasada == 2) emitir_byte("00000001");
        return;
    }
    if (strcmp(mnem, "RET")    == 0) {
        current_addr += 1;
        if (pasada == 2) emitir_byte("00000010");
        return;
    }
    if (strcmp(mnem, "IRET")   == 0) {
        current_addr += 1;
        if (pasada == 2) emitir_byte("00000011");
        return;
    }
    if (strcmp(mnem, "FPU_OP") == 0) {
        current_addr += 1;
        if (pasada == 2) emitir_byte("00000100");
        return;
    }

    /* ── Instrucciones de 4 bytes ── */
    if (strcmp(mnem, "MOVI") == 0) {
        char ra_s[8]; int imm8;
        sscanf(p, "%[^,], %d", ra_s, &imm8);
        int ra = reg_num(ra_s);
        current_addr += 4;
        if (pasada == 2) emit_movi(ra, imm8);
        return;
    }
    if (strcmp(mnem, "ADDI") == 0) {
        char ra_s[8]; int imm8;
        sscanf(p, "%[^,], %d", ra_s, &imm8);
        int ra = reg_num(ra_s);
        current_addr += 4;
        if (pasada == 2) emit_addi(ra, imm8);
        return;
    }

    /* ── Instrucciones RR de 2 bytes ── */
    char ra_s[8], rb_s[8];
    if (strcmp(mnem, "MOV")  == 0) {
        sscanf(p, "%[^,], %s", ra_s, rb_s);
        current_addr += 2;
        if (pasada == 2) emit_rr("0100000", reg_num(ra_s), reg_num(rb_s));
        return;
    }
    if (strcmp(mnem, "XCHG") == 0) {
        sscanf(p, "%[^,], %s", ra_s, rb_s);
        current_addr += 2;
        if (pasada == 2) emit_rr("0100001", reg_num(ra_s), reg_num(rb_s));
        return;
    }
    if (strcmp(mnem, "ADD")  == 0) {
        sscanf(p, "%[^,], %s", ra_s, rb_s);
        current_addr += 2;
        if (pasada == 2) emit_rr("0100100", reg_num(ra_s), reg_num(rb_s));
        return;
    }
    if (strcmp(mnem, "SUB")  == 0) {
        sscanf(p, "%[^,], %s", ra_s, rb_s);
        current_addr += 2;
        if (pasada == 2) emit_rr("0100101", reg_num(ra_s), reg_num(rb_s));
        return;
    }
    if (strcmp(mnem, "MUL")  == 0) {
        sscanf(p, "%[^,], %s", ra_s, rb_s);
        current_addr += 2;
        if (pasada == 2) emit_rr("0100110", reg_num(ra_s), reg_num(rb_s));
        return;
    }
    if (strcmp(mnem, "DIV")  == 0) {
        sscanf(p, "%[^,], %s", ra_s, rb_s);
        current_addr += 2;
        if (pasada == 2) emit_rr("0100111", reg_num(ra_s), reg_num(rb_s));
        return;
    }
    if (strcmp(mnem, "ADC")  == 0) {
        sscanf(p, "%[^,], %s", ra_s, rb_s);
        current_addr += 2;
        if (pasada == 2) emit_rr("0101000", reg_num(ra_s), reg_num(rb_s));
        return;
    }
    if (strcmp(mnem, "SBB")  == 0) {
        sscanf(p, "%[^,], %s", ra_s, rb_s);
        current_addr += 2;
        if (pasada == 2) emit_rr("0101001", reg_num(ra_s), reg_num(rb_s));
        return;
    }
    if (strcmp(mnem, "AND")  == 0) {
        sscanf(p, "%[^,], %s", ra_s, rb_s);
        current_addr += 2;
        if (pasada == 2) emit_rr("0101101", reg_num(ra_s), reg_num(rb_s));
        return;
    }
    if (strcmp(mnem, "XOR")  == 0) {
        sscanf(p, "%[^,], %s", ra_s, rb_s);
        current_addr += 2;
        if (pasada == 2) emit_rr("0101110", reg_num(ra_s), reg_num(rb_s));
        return;
    }
    if (strcmp(mnem, "XORA") == 0) {
        sscanf(p, "%[^,], %s", ra_s, rb_s);
        current_addr += 2;
        if (pasada == 2) emit_rr("0101111", reg_num(ra_s), reg_num(rb_s));
        return;
    }
    if (strcmp(mnem, "CMP")  == 0) {
        sscanf(p, "%[^,], %s", ra_s, rb_s);
        current_addr += 2;
        if (pasada == 2) emit_rr("0110000", reg_num(ra_s), reg_num(rb_s));
        return;
    }
    if (strcmp(mnem, "TEST") == 0) {
        sscanf(p, "%[^,], %s", ra_s, rb_s);
        current_addr += 2;
        if (pasada == 2) emit_rr("0110001", reg_num(ra_s), reg_num(rb_s));
        return;
    }

    /* ── Instrucciones R de 2 bytes ── */
    if (strcmp(mnem, "PUSH") == 0) {
        sscanf(p, "%s", ra_s);
        current_addr += 2;
        if (pasada == 2) emit_r("0100010", reg_num(ra_s));
        return;
    }
    if (strcmp(mnem, "POP")  == 0) {
        sscanf(p, "%s", ra_s);
        current_addr += 2;
        if (pasada == 2) emit_r("0100011", reg_num(ra_s));
        return;
    }
    if (strcmp(mnem, "INC")  == 0) {
        sscanf(p, "%s", ra_s);
        current_addr += 2;
        if (pasada == 2) emit_r("0101010", reg_num(ra_s));
        return;
    }
    if (strcmp(mnem, "DEC")  == 0) {
        sscanf(p, "%s", ra_s);
        current_addr += 2;
        if (pasada == 2) emit_r("0101011", reg_num(ra_s));
        return;
    }
    if (strcmp(mnem, "NEG")  == 0) {
        sscanf(p, "%s", ra_s);
        current_addr += 2;
        if (pasada == 2) emit_r("0101100", reg_num(ra_s));
        return;
    }
    if (strcmp(mnem, "NOT")  == 0) {
        sscanf(p, "%s", ra_s);
        current_addr += 2;
        if (pasada == 2) emit_r("0110010", reg_num(ra_s));
        return;
    }
    if (strcmp(mnem, "SHL")  == 0) {
        sscanf(p, "%s", ra_s);
        current_addr += 2;
        if (pasada == 2) emit_r("0110011", reg_num(ra_s));
        return;
    }
    if (strcmp(mnem, "SHR")  == 0) {
        sscanf(p, "%s", ra_s);
        current_addr += 2;
        if (pasada == 2) emit_r("0110100", reg_num(ra_s));
        return;
    }
    if (strcmp(mnem, "ROL")  == 0) {
        sscanf(p, "%s", ra_s);
        current_addr += 2;
        if (pasada == 2) emit_r("0110101", reg_num(ra_s));
        return;
    }
    if (strcmp(mnem, "ROR")  == 0) {
        sscanf(p, "%s", ra_s);
        current_addr += 2;
        if (pasada == 2) emit_r("0110110", reg_num(ra_s));
        return;
    }

    /* ── Instrucciones DIR de 8 bytes ── */
    char dest[64];
    if (strcmp(mnem, "JMP")  == 0) {
        sscanf(p, "%s", dest);
        current_addr += 8;
        if (pasada == 2) {
            int dir = isdigit(dest[0]) ? atoi(dest) : buscar_label(dest);
            emit_dir("1100000", dir);
        }
        return;
    }
    if (strcmp(mnem, "JZ")   == 0) {
        sscanf(p, "%s", dest);
        current_addr += 8;
        if (pasada == 2) {
            int dir = isdigit(dest[0]) ? atoi(dest) : buscar_label(dest);
            emit_dir("1100001", dir);
        }
        return;
    }
    if (strcmp(mnem, "JNZ")  == 0) {
        sscanf(p, "%s", dest);
        current_addr += 8;
        if (pasada == 2) {
            int dir = isdigit(dest[0]) ? atoi(dest) : buscar_label(dest);
            emit_dir("1100010", dir);
        }
        return;
    }
    if (strcmp(mnem, "JC")   == 0) {
        sscanf(p, "%s", dest);
        current_addr += 8;
        if (pasada == 2) {
            int dir = isdigit(dest[0]) ? atoi(dest) : buscar_label(dest);
            emit_dir("1100011", dir);
        }
        return;
    }
    if (strcmp(mnem, "JNC")  == 0) {
        sscanf(p, "%s", dest);
        current_addr += 8;
        if (pasada == 2) {
            int dir = isdigit(dest[0]) ? atoi(dest) : buscar_label(dest);
            emit_dir("1100100", dir);
        }
        return;
    }
    if (strcmp(mnem, "CALL") == 0) {
        sscanf(p, "%s", dest);
        current_addr += 8;
        if (pasada == 2) {
            int dir = isdigit(dest[0]) ? atoi(dest) : buscar_label(dest);
            emit_dir("1100101", dir);
        }
        return;
    }

    /* ── Instrucciones R_DIR de 8 bytes ── */
    if (strcmp(mnem, "LOAD")  == 0) {
        sscanf(p, "%[^,], %s", ra_s, dest);
        char *d = dest;
        if (*d == '[') d++;
        char *br = strchr(d, ']');
        if (br) *br = '\0';
        current_addr += 8;
        if (pasada == 2) {
            int dir = isdigit(d[0]) ? atoi(d) : buscar_label(d);
            emit_r_dir("1100001", reg_num(ra_s), dir);
        }
        return;
    }
    if (strcmp(mnem, "STORE") == 0) {
        sscanf(p, "%[^,], %s", ra_s, dest);
        char *d = dest;
        if (*d == '[') d++;
        char *br = strchr(d, ']');
        if (br) *br = '\0';
        current_addr += 8;
        if (pasada == 2) {
            int dir = isdigit(d[0]) ? atoi(d) : buscar_label(d);
            emit_r_dir("1100010", reg_num(ra_s), dir);
        }
        return;
    }
    if (strcmp(mnem, "LEA")   == 0) {
        sscanf(p, "%[^,], %s", ra_s, dest);
        current_addr += 8;
        if (pasada == 2) {
            int dir = isdigit(dest[0]) ? atoi(dest) : buscar_label(dest);
            emit_r_dir("1100011", reg_num(ra_s), dir);
        }
        return;
    }

    fprintf(stderr,
        "[ENSAMBLADOR] Advertencia: mnemónico desconocido '%s'\n", mnem);
}

/* ════════════════════════════════════════
   MAIN — DOS PASADAS
   ════════════════════════════════════════ */

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Uso: %s archivo.asm [salida.txt]\n", argv[0]);
        return 1;
    }

    /* ── PASADA 1: recolectar etiquetas ── */
    fprintf(stderr, "[ENSAMBLADOR] Pasada 1: recolectando etiquetas...\n");
    pasada = 1;
    current_addr = 0;

    FILE *f1 = fopen(argv[1], "r");
    if (!f1) {
        fprintf(stderr, "Error: no se puede abrir '%s'\n", argv[1]);
        return 1;
    }
    char linea[256];
    while (fgets(linea, sizeof(linea), f1))
        ensamblar_linea(linea);
    fclose(f1);

    fprintf(stderr, "[ENSAMBLADOR] Etiquetas encontradas: %d\n", num_labels);

    /* ── PASADA 2: generar binario ── */
    fprintf(stderr, "[ENSAMBLADOR] Pasada 2: generando binario...\n");
    pasada = 2;
    current_addr = 0;
    num_output = 0;

    FILE *f2 = fopen(argv[1], "r");
    if (!f2) {
        fprintf(stderr, "Error: no se puede abrir '%s'\n", argv[1]);
        return 1;
    }
    while (fgets(linea, sizeof(linea), f2))
        ensamblar_linea(linea);
    fclose(f2);

    /* ── SALIDA ── */
    FILE *out = stdout;
    if (argc == 3) {
        out = fopen(argv[2], "w");
        if (!out) {
            fprintf(stderr, "Error: no se puede crear '%s'\n", argv[2]);
            return 1;
        }
    }

    fprintf(stderr, "[ENSAMBLADOR] Bytes generados: %d\n", num_output);
    for (int i = 0; i < num_output; i++)
        fprintf(out, "%s\n", output[i]);

    if (argc == 3) fclose(out);
    return 0;
}