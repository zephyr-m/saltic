#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
seed_enter_dev_shell "$0" "$@"

seed_stage 8 "замыкание"

seed_require_file "soul/seed/tests/closure.saltic"
seed_require_file "soul/seed/tests/expected/closure.txt"
seed_require_absent_file "os/bootstrap/linux-memory.S"
seed_require_absent_file "os/target/qemu_virt/platform.S"
seed_require_absent_file "tests/fixtures/vm-canonical.S"

seed_forbid_pattern \
    'riscv32-(none-elf-)?(as|gcc|ld|objcopy)' \
    "$repo_root/justfile" \
    "$repo_root/os/bootstrap" \
    "$repo_root/os/target/qemu_virt" \
    "$repo_root/tests"

seed_pending "замыкание" \
    "нет прямого ELF bootstrap stage 1 -> stage 2 -> stage 3" \
    "не доказано побайтовое равенство самостоятельно созданных stage 2 и stage 3" \
    "каноническая программа ещё не проходит весь закрытый путь без .s и GNU toolchain"
