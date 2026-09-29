#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
seed_enter_dev_shell "$0" "$@"

seed_stage 6 "host ELF"

seed_pending "host ELF" \
    "compiler/runtime ещё не создают host ELF напрямую через machine.Program" \
    "один и тот же созданный ELF не запускается в process-mode собственной VM и qemu-riscv32" \
    "не сравниваются stdout, stderr, exit code, arguments и virtual files двух исполнителей"
