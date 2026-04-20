# ============================================================
#  euclides.asm
#  Algoritmo de Euclides iterativo (version del prof. Pena)
#
#  Memoria:
#    [375]  = operando A  (ej: 48)
#    [1535] = operando B  (ej: 18)
#    [7478] = resultado (MCD)
#
#  Codigo almacenado desde posicion 2500
#  (el ensamblador genera binario absoluto desde addr 0;
#   se carga en el simulador/enlazador a partir de 2500)
#
#  Algoritmo:
#    mientras B != 0:
#        temp = A mod B   (A - B*(A/B), usamos restas sucesivas)
#        A = B
#        B = temp
#    resultado = A
# ============================================================

# ---- Inicializar punteros de datos ----
        MOVI  R6, 0          # R6 = 0 (base alta = 0, solo usamos 8 bits bajos)

# ---- Cargar A desde posicion 375 ----
        LOAD  R0, [375]      # R0 = Mem[375]  (operando A)

# ---- Cargar B desde posicion 1535 ----
        LOAD  R1, [1535]     # R1 = Mem[1535] (operando B)

# ---- Bucle Euclides: while (R1 != 0) ----
euclides_loop:
        MOVI  R2, 0          # R2 = 0 (comparador cero)
        CMP   R1, R2         # flags: R1 == 0 ?
        JZ    euclides_done  # si B == 0, terminar

# ---- Calcular R0 mod R1 mediante restas sucesivas ----
#      R3 = R0 (copia de A para hacer restas)
        MOV   R3, R0         # R3 = A

mod_loop:
        CMP   R3, R1         # R3 < R1 ?
        JC    mod_done       # si carry (R3 < R1), terminar restas
        SUB   R3, R1         # R3 = R3 - R1
        JMP   mod_loop

mod_done:
#      Ahora R3 = A mod B
#      A = B  -->  R0 = R1
        MOV   R0, R1         # R0 = B
#      B = temp --> R1 = R3
        MOV   R1, R3         # R1 = A mod B
        JMP   euclides_loop

euclides_done:
# ---- Guardar resultado en posicion 7478 ----
        STORE R0, [7478]     # Mem[7478] = MCD

# ---- Fin ----
        HALT