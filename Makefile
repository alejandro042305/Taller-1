# ══════════════════════════════════════════════════════
#  Makefile — SPL NB-64
#  Uso: make all       → compila los 4 modulos
#       make test      → prueba con suma.spl y suma.asm
#       make clean     → elimina binarios y archivos generados
# ══════════════════════════════════════════════════════

SRC     = src
PROG    = programs
OUT     = output

CC      = gcc
FLEX    = flex
CFLAGS  = -lfl

.PHONY: all clean test dirs \
        preprocesador ensamblador enlazador lexico

# ── Objetivo principal ──────────────────────────────
all: dirs preprocesador ensamblador enlazador lexico
	@echo ""
	@echo "============================================"
	@echo "  SPL NB-64: todos los modulos compilados"
	@echo "============================================"

# ── Crear directorios si no existen ────────────────
dirs:
	@mkdir -p $(OUT)

# ── Modulo A: Preprocesador ─────────────────────────
preprocesador: $(SRC)/preprocesador
$(SRC)/preprocesador: $(SRC)/preprocesador.l
	@echo "[1/4] Compilando preprocesador..."
	sed -i 's/\r//' $(SRC)/preprocesador.l
	cd $(SRC) && $(FLEX) preprocesador.l && $(CC) -o preprocesador lex.yy.c $(CFLAGS)
	@echo "      OK → $(SRC)/preprocesador"

# ── Modulo B: Ensamblador ───────────────────────────
ensamblador: $(SRC)/ensamblador
$(SRC)/ensamblador: $(SRC)/ensamblador.l
	@echo "[2/4] Compilando ensamblador..."
	sed -i 's/\r//' $(SRC)/ensamblador.l
	cd $(SRC) && $(FLEX) ensamblador.l && $(CC) -o ensamblador lex.yy.c $(CFLAGS)
	@echo "      OK → $(SRC)/ensamblador"

# ── Modulo C: Enlazador ─────────────────────────────
enlazador: $(SRC)/enlazador
$(SRC)/enlazador: $(SRC)/enlazador.l
	@echo "[3/4] Compilando enlazador..."
	sed -i 's/\r//' $(SRC)/enlazador.l
	cd $(SRC) && $(FLEX) enlazador.l && $(CC) -o enlazador lex.yy.c $(CFLAGS)
	@echo "      OK → $(SRC)/enlazador"

# ── Modulo D: Analizador Lexico ─────────────────────
lexico: $(SRC)/lexico
$(SRC)/lexico: $(SRC)/lexico.l
	@echo "[4/4] Compilando analizador lexico..."
	sed -i 's/\r//' $(SRC)/lexico.l
	cd $(SRC) && $(FLEX) lexico.l && $(CC) -o lexico lex.yy.c $(CFLAGS)
	@echo "      OK → $(SRC)/lexico"

# ── Pruebas ─────────────────────────────────────────
test: all
	@echo ""
	@echo "--- Prueba preprocesador (suma.spl) ---"
	$(SRC)/preprocesador $(PROG)/suma.spl > $(OUT)/suma_expandido.spl
	@cat $(OUT)/suma_expandido.spl

	@echo ""
	@echo "--- Prueba ensamblador (suma.asm) ---"
	$(SRC)/ensamblador $(PROG)/suma.asm > $(OUT)/suma.obj
	@cat $(OUT)/suma.obj

	@echo ""
	@echo "--- Prueba enlazador (suma.obj) ---"
	$(SRC)/enlazador $(OUT)/suma.obj -o $(OUT)/suma.bin
	@cat $(OUT)/suma.bin

	@echo ""
	@echo "--- Prueba lexico (suma.spl) ---"
	$(SRC)/lexico $(PROG)/suma.spl

# ── Limpieza ────────────────────────────────────────
clean:
	@echo "Limpiando..."
	rm -f $(SRC)/preprocesador $(SRC)/ensamblador \
	      $(SRC)/enlazador $(SRC)/lexico \
	      $(SRC)/lex.yy.c \
	      $(OUT)/*.obj $(OUT)/*.bin $(OUT)/*.spl
	@echo "Listo."