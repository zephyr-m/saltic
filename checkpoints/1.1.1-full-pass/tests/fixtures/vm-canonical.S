.option norvc
.option norelax

.section .text
.global _start

_start:
    addi s10, a0, 0
    addi s11, a1, 0
    addi t0, zero, 2
    blt s10, t0, .L_bad_arguments

    lw t0, 4(s11)
    lbu t0, 0(t0)
    addi t1, zero, 110
    beq t0, t1, .L_normal
    addi t1, zero, 98
    beq t0, t1, .L_break
    addi t1, zero, 105
    beq t0, t1, .L_illegal
    addi t1, zero, 112
    beq t0, t1, .L_misaligned_pc
    addi t1, zero, 108
    beq t0, t1, .L_load_fault
    addi t1, zero, 115
    beq t0, t1, .L_store_fault
    addi t1, zero, 117
    beq t0, t1, .L_unsupported_ecall
    addi t1, zero, 116
    beq t0, t1, .L_step_limit
    jal zero, .L_bad_arguments

.L_normal:
    addi t0, zero, 4
    blt s10, t0, .L_bad_arguments

    # Upper immediates: LUI, AUIPC.
    lui t0, 0x12345
    lui t1, 0x12345
    bne t0, t1, .L_failed
    auipc t0, 0
    auipc t1, 0
    addi t0, t0, 4
    bne t0, t1, .L_failed

    # Jumps: JAL, JALR.
    addi s0, zero, 0
    jal ra, .L_jal_target
.L_after_jal:
    addi t0, zero, 1
    bne s0, t0, .L_failed
    jal zero, .L_jumps_done
.L_jal_target:
    addi s0, zero, 1
    jalr zero, 0(ra)
.L_jumps_done:

    # Branches: BEQ, BNE, BLT, BGE, BLTU, BGEU.
    addi t0, zero, 5
    addi t1, zero, 5
    beq t0, t1, .L_beq_ok
    jal zero, .L_failed
.L_beq_ok:
    addi t1, zero, 6
    bne t0, t1, .L_bne_ok
    jal zero, .L_failed
.L_bne_ok:
    addi t0, zero, -1
    addi t1, zero, 0
    blt t0, t1, .L_blt_ok
    jal zero, .L_failed
.L_blt_ok:
    bge t1, t0, .L_bge_ok
    jal zero, .L_failed
.L_bge_ok:
    bltu t1, t0, .L_bltu_ok
    jal zero, .L_failed
.L_bltu_ok:
    bgeu t0, t1, .L_bgeu_ok
    jal zero, .L_failed
.L_bgeu_ok:

    # Loads and stores: LB, LH, LW, LBU, LHU, SB, SH, SW.
    la t0, vm_cells
    addi t1, zero, -1
    sb t1, 0(t0)
    lb t2, 0(t0)
    bne t1, t2, .L_failed
    lbu t2, 0(t0)
    addi t3, zero, 255
    bne t2, t3, .L_failed

    addi t1, zero, -2
    sh t1, 2(t0)
    lh t2, 2(t0)
    bne t1, t2, .L_failed
    lhu t2, 2(t0)
    lui t3, 0x10
    addi t3, t3, -2
    bne t2, t3, .L_failed

    lui t1, 0x12345
    addi t1, t1, 0x678
    sw t1, 4(t0)
    lw t2, 4(t0)
    bne t1, t2, .L_failed

    # Immediate arithmetic: ADDI, SLTI, SLTIU, XORI, ORI, ANDI,
    # SLLI, SRLI, SRAI.
    addi t0, zero, 7
    slti t1, t0, 8
    addi t2, zero, 1
    bne t1, t2, .L_failed
    sltiu t1, t0, -1
    bne t1, t2, .L_failed
    xori t1, t0, 3
    addi t2, zero, 4
    bne t1, t2, .L_failed
    ori t1, t0, 8
    addi t2, zero, 15
    bne t1, t2, .L_failed
    andi t1, t2, 6
    addi t2, zero, 6
    bne t1, t2, .L_failed
    addi t0, zero, 1
    slli t1, t0, 5
    addi t2, zero, 32
    bne t1, t2, .L_failed
    addi t0, zero, -1
    srli t1, t0, 28
    addi t2, zero, 15
    bne t1, t2, .L_failed
    addi t0, zero, -16
    srai t1, t0, 2
    addi t2, zero, -4
    bne t1, t2, .L_failed

    # Register arithmetic: ADD, SUB, SLL, SLT, SLTU, XOR, SRL,
    # SRA, OR, AND.
    addi t0, zero, 7
    addi t1, zero, 5
    add t2, t0, t1
    addi t3, zero, 12
    bne t2, t3, .L_failed
    sub t2, t0, t1
    addi t3, zero, 2
    bne t2, t3, .L_failed
    addi t0, zero, 1
    addi t1, zero, 3
    sll t2, t0, t1
    addi t3, zero, 8
    bne t2, t3, .L_failed
    addi t0, zero, -1
    addi t1, zero, 1
    slt t2, t0, t1
    bne t2, t1, .L_failed
    sltu t2, t1, t0
    bne t2, t1, .L_failed
    addi t0, zero, 10
    addi t1, zero, 12
    xor t2, t0, t1
    addi t3, zero, 6
    bne t2, t3, .L_failed
    lui t0, 0x80000
    addi t1, zero, 31
    srl t2, t0, t1
    addi t3, zero, 1
    bne t2, t3, .L_failed
    sra t2, t0, t1
    addi t3, zero, -1
    bne t2, t3, .L_failed
    addi t0, zero, 10
    addi t1, zero, 12
    or t2, t0, t1
    addi t3, zero, 14
    bne t2, t3, .L_failed
    and t2, t0, t1
    addi t3, zero, 8
    bne t2, t3, .L_failed

    fence

    # openat/read/lseek/close for the input file.
    lw s1, 8(s11)
    lw s2, 12(s11)
    addi a0, zero, -100
    addi a1, s1, 0
    addi a2, zero, 0
    addi a3, zero, 0
    addi a7, zero, 56
    ecall
    addi s3, a0, 0
    blt s3, zero, .L_failed

    addi a0, s3, 0
    la a1, vm_buffer
    addi a2, zero, 5
    addi a7, zero, 63
    ecall
    addi t0, zero, 5
    bne a0, t0, .L_failed

    addi a0, s3, 0
    addi a1, zero, -2
    addi a2, zero, 1
    addi a7, zero, 62
    ecall
    addi t0, zero, 3
    bne a0, t0, .L_failed

    addi a0, s3, 0
    addi a1, zero, -6
    addi a2, zero, 2
    addi a7, zero, 62
    ecall
    addi t0, zero, 3
    bne a0, t0, .L_failed

    addi a0, s3, 0
    addi a1, zero, 0
    addi a2, zero, 0
    addi a7, zero, 62
    ecall
    bne a0, zero, .L_failed

    addi a0, s3, 0
    la a1, vm_buffer
    addi a2, zero, 9
    addi a7, zero, 63
    ecall
    addi t0, zero, 9
    bne a0, t0, .L_failed

    addi a0, s3, 0
    addi a7, zero, 57
    ecall
    bne a0, zero, .L_failed

    # openat/write/lseek/close for the output file.
    addi a0, zero, -100
    addi a1, s2, 0
    addi a2, zero, 0x241
    addi a3, zero, 0x1b6
    addi a7, zero, 56
    ecall
    addi s3, a0, 0
    blt s3, zero, .L_failed

    addi a0, s3, 0
    la a1, vm_buffer
    addi a2, zero, 9
    addi a7, zero, 64
    ecall
    addi t0, zero, 9
    bne a0, t0, .L_failed

    addi a0, s3, 0
    addi a1, zero, 0
    addi a2, zero, 0
    addi a7, zero, 62
    ecall
    bne a0, zero, .L_failed

    addi a0, s3, 0
    la a1, vm_prefix
    addi a2, zero, 3
    addi a7, zero, 64
    ecall
    addi t0, zero, 3
    bne a0, t0, .L_failed

    addi a0, s3, 0
    addi a7, zero, 57
    ecall
    bne a0, zero, .L_failed

    addi a0, zero, 1
    la a1, vm_ok
    addi a2, zero, 17
    addi a7, zero, 64
    ecall

    addi a0, zero, 37
    addi a7, zero, 93
    ecall

.L_break:
    ebreak

.L_illegal:
    .word 0xffffffff

.balign 4
.L_misaligned_pc:
    la t0, .L_pc_target
    addi t0, t0, 2
    jalr zero, 0(t0)
.L_pc_target:
    jal zero, .L_failed

.L_load_fault:
    lui t0, 0x4000
    lw t1, 0(t0)
    jal zero, .L_failed

.L_store_fault:
    lui t0, 0x4000
    sw t1, 0(t0)
    jal zero, .L_failed

.L_unsupported_ecall:
    addi a7, zero, 123
    ecall
    jal zero, .L_failed

.L_step_limit:
    jal zero, .L_step_limit

.L_bad_arguments:
    addi a0, zero, 98
    addi a7, zero, 93
    ecall

.L_failed:
    addi a0, zero, 1
    la a1, vm_failed
    addi a2, zero, 21
    addi a7, zero, 64
    ecall
    addi a0, zero, 99
    addi a7, zero, 93
    ecall

.section .rodata
vm_ok:
    .ascii "vm-canonical: ok\n"
vm_failed:
    .ascii "vm-canonical: failed\n"
vm_prefix:
    .ascii "VM:"

.section .bss
.balign 8
vm_cells:
    .space 16
vm_buffer:
    .space 32
