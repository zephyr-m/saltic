#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
seed_enter_dev_shell "$0" "$@"

seed_stage 3 "машинные слова"
seed_run_current machine

machine_work="$seed_work_root/machine-qemu"
mkdir -p "$machine_work/build"

(
    cd "$repo_root"
    SALTIC_BUILD_DIR="$machine_work/build" \
    SALTIC_HEAP_BYTES=536870912 \
        bash os/bootstrap/build.sh \
        soul/seed/tests/machine/qemu.saltic \
        "$machine_work/generator.elf"
    qemu-riscv32 -B 0x100000000 \
        "$machine_work/generator.elf" \
        "$machine_work/generated.elf"
    test -s "$machine_work/generated.elf"
    chmod +x "$machine_work/generated.elf"
    qemu-riscv32 -B 0x100000000 "$machine_work/generated.elf"
)

printf 'seed 3/8: машинные слова и собственный ELF подтверждены VM + QEMU\n'
