# ============================================================
#  fibonacci.asm
#  Fibonacci iterativo: calcula F(N)
#
#  Memoria:
#    [500] = N (entrada: qué término de Fibonacci calcular)
#    [510] = resultado F(N)
#
#  Registros:
#    R0 = F(i-1)  -- "anterior"
#    R1 = F(i)    -- "actual"
#    R2 = temp    -- intercambio
#    R3 = contador i
#    R4 = N       -- valor leído de memoria
#    R5 = 0       -- constante cero para comparaciones
#
#  Ejemplo: N=8 -> F(8) = 21
#    F: 0,1,1,2,3,5,8,13,21,...
# ============================================================

        LOAD  R4, [500]      # R4 = N

# ---- Casos base ----
        MOVI  R5, 0          # R5 = 0 (constante)
        CMP   R4, R5         # N == 0?
        JZ    fib_cero       # si N=0, resultado=0

        MOVI  R2, 1
        CMP   R4, R2         # N == 1?
        JZ    fib_uno        # si N=1, resultado=1

# ---- Caso general: iterar desde 2 hasta N ----
        MOVI  R0, 0          # R0 = F(0) = 0
        MOVI  R1, 1          # R1 = F(1) = 1
        MOVI  R3, 2          # R3 = i = 2

fib_loop:
        CMP   R3, R4         # i > N?
        JC    fib_loop_body  # si i < N, continuar  (carry = i<N)
        CMP   R4, R3         # N == i? (necesitamos i<=N)
        JZ    fib_loop_body
        JMP   fib_fin        # i > N, salir

fib_loop_body:
        MOV   R2, R1         # temp = actual
        ADD   R1, R0         # actual = actual + anterior
        MOV   R0, R2         # anterior = temp
        INC   R3             # i++
        JMP   fib_loop

fib_fin:
        STORE R1, [510]      # resultado = F(N)
        HALT

fib_cero:
        MOVI  R1, 0
        STORE R1, [510]
        HALT

fib_uno:
        MOVI  R1, 1
        STORE R1, [510]
        HALT
