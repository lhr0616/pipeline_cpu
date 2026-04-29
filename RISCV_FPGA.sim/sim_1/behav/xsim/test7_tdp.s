        addi x31, x0, 320
        lui x1, 0x87654
        addi x1, x1, 0x321
        sw x1, 4(x31)
        lw x30, -40(x31)
        lw x2, -24(x31)
        slli x3, x2, 24
        srli x4, x3, 24
        add x5, x4, x4
        jal x6, aaaa
        bge x5, x4, bbbb
aaaa:   jalr x7, x6, 0
bbbb:   sltu x8, x4, x5
        andi x9, x8, 0x001
        sltiu x10, x1, 0x001
        slti x11, x1, 0x001
        xori x12, x1, 0x001
        ori x13, x1, 0x00F
        srai x14, x1, 24
        sub x15, x5, x4
        sll x16, x1, x4
        srl x17, x1, x4
        sra x18, x1, x4
        slt x19, x4, x5
        sltu x20, x4, x1
        xor x21, x4, x5
        or x22, x4, x5
        and x23, x4, x5
        blt x5, x4, bbbb
        bltu x1, x5, bbbb
        bgeu x5, x1, bbbb
        beq x4, x15, cccc
        sw x23, 0(x0)
        jal x24, bbbb
cccc:   auipc x25, 0x87654
        sw x2, 8(x31)
        sw x3, 12(x31)
        sw x4, 16(x31)
        sw x5, 20(x31)
        sw x6, 24(x31)
        sw x7, 28(x31)
        sw x8, 32(x31)
        sw x9, 36(x31)
        sw x10, 40(x31)
        sw x11, 44(x31)
        sw x12, 48(x31)
        sw x13, 52(x31)
        sw x14, 56(x31)
        sw x15, 60(x31)
        sw x16, 64(x31)
        sw x17, 68(x31)
        sw x18, 72(x31)
        sw x19, 76(x31)
        sw x20, 80(x31)
        sw x21, 84(x31)
        sw x22, 88(x31)
        sw x23, 92(x31)
        sw x24, 96(x31)
        sw x25, 100(x31)
        lb x26, 280(x0)
        sw x26, 104(x31)
        lh x27, 280(x0)
        lbu x28, 280(x0)
        sw x27, 108(x31)
        sw x28, 112(x31)
        lhu x29, 280(x0)
        sw x29, 116(x31)
        sb x30, 120(x31)
        sh x30, 124(x31)
dddd:   jal x30, dddd
