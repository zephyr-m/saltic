#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root"

work="${SALTIC_QEMU_GRAPHICS_DIR:-.cache/build/qemu-graphics}"
mkdir -p "$work"
target_heap_bytes="${SALTIC_QEMU_HEAP_BYTES:-67108864}"

echo "графика: собираю qemu-virt toolchain"
SALTIC_BUILD_DIR="$work/toolchain-build" \
    bash os/bootstrap/build.sh \
    os/target/qemu_virt/toolchain.saltic \
    "$work/toolchain.elf"

echo "графика: собираю bare-metal ELF $work/program.elf"
qemu-riscv32 -B 0x100000000 \
    "$work/toolchain.elf" \
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
    test -x "$work/program.elf"
    echo "графика: прямой ELF подтверждён"
fi
