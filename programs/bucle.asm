# Contar de 0 a 4
        MOVI R0, 0
        MOVI R1, 5
loop:
        INC  R0
        CMP  R0, R1
        JNZ  loop
        HALT