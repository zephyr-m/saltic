#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root"

work="${SALTIC_QEMU_GRAPHICS_DIR:-.cache/build/qemu-graphics}"
mkdir -p "$work"
target_heap_bytes="${SALTIC_QEMU_HEAP_BYTES:-67108864}"

echo "графика: беру qemu-virt toolchain из bootstrap/"
source bootstrap/names.sh
toolchain="$(saltic_qemu_virt_compiler)"

echo "графика: собираю bare-metal ELF $work/program.elf"
qemu-riscv32 -B 0x100000000 \
    "$toolchain" \
    os/main.saltic \
    "$work/program.elf" \
    "$target_heap_bytes"

echo "графика: сборка готова"

if [[ "${1:-}" == "--check" ]]; then
    magic="$(od -An -tx1 -N4 "$work/program.elf" | tr -d '[:space:]')"
    if [[ "$magic" != "7f454c46" ]]; then
        echo "графика: компилятор не создал ELF" >&2
        exit 1
    fi
    test -s "$work/program.elf"
    echo "графика: прямой ELF подтверждён"
fi
