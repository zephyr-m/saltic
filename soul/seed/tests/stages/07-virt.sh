#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
seed_enter_dev_shell "$0" "$@"

seed_stage 7 "qemu-virt ELF"

seed_pending "qemu-virt ELF" \
    "нет Saltic-owned start, traps, UART и platform contract без platform.S" \
    "VM ещё не исполняет csrrw, csrrs, mret, wfi и полный 32-битный address space" \
    "один и тот же virt ELF не запускается в machine-mode собственной VM и qemu-system-riscv32" \
    "не сравниваются UART, traps и exit двух исполнителей"
