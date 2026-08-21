.option norvc
.option norelax

.equ UART_BASE, 0x10000000
.equ UART_LSR, 5
.equ UART_TX_READY, 0x20
.equ QEMU_TEST, 0x00100000
.equ QEMU_EXIT_OK, 0x5555
.equ QEMU_EXIT_ERROR, 0x3333

.section .text.platform_start
.global platform_start
platform_start:
  la sp, __stack_top
  la t0, platform_trap
  csrw mtvec, t0
  la a1, platform_argv
  addi a0, zero, 1
  addi sp, sp, -16
  sw a0, 0(sp)
  la t0, platform_name
  sw t0, 4(sp)
  sw zero, 8(sp)
  sw zero, 12(sp)
  j _start

.section .text
.align 2
platform_trap:
  csrr t0, mcause
  addi t1, zero, 11
  bne t0, t1, platform_exit_error

  addi t0, zero, 64
  beq a7, t0, platform_write
  addi t0, zero, 93
  beq a7, t0, platform_exit
  addi t0, zero, 94
  beq a7, t0, platform_exit
  j platform_exit_error

.global rt_platform_write
rt_platform_write:
  addi t0, a1, 0
  addi t1, a2, 0
  li t4, UART_BASE
.L_platform_direct_write_loop:
  beq t1, zero, .L_platform_direct_write_done
.L_platform_direct_uart_wait:
  lbu t2, UART_LSR(t4)
  andi t2, t2, UART_TX_READY
  beq t2, zero, .L_platform_direct_uart_wait
  lbu t2, 0(t0)
  sb t2, 0(t4)
  addi t0, t0, 1
  addi t1, t1, -1
  j .L_platform_direct_write_loop
.L_platform_direct_write_done:
  addi a0, a2, 0
  jalr zero, 0(ra)

.global rt_platform_exit
rt_platform_exit:
  beq a0, zero, platform_exit_ok
  j platform_exit_error

platform_write:
  addi t0, a1, 0
  addi t1, a2, 0
  addi t3, a2, 0
  li t4, UART_BASE
.L_platform_write_loop:
  beq t1, zero, .L_platform_write_done
.L_platform_uart_wait:
  lbu t2, UART_LSR(t4)
  andi t2, t2, UART_TX_READY
  beq t2, zero, .L_platform_uart_wait
  lbu t2, 0(t0)
  sb t2, 0(t4)
  addi t0, t0, 1
  addi t1, t1, -1
  j .L_platform_write_loop
.L_platform_write_done:
  addi a0, t3, 0
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret

platform_exit:
  beq a0, zero, platform_exit_ok
platform_exit_error:
  li t0, QEMU_TEST
  li t1, QEMU_EXIT_ERROR
  sw t1, 0(t0)
  j platform_halt
platform_exit_ok:
#ifdef SALTIC_KEEP_SCREEN
  j platform_halt
#else
  li t0, QEMU_TEST
  li t1, QEMU_EXIT_OK
  sw t1, 0(t0)
#endif
platform_halt:
  wfi
  j platform_halt

.section .rodata
.align 2
platform_name:
  .asciz "saltic"

.section .data
.align 2
platform_argv:
  .word platform_name
  .word 0
