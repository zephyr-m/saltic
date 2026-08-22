#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root"

work=".cache/build/qemu-graphics"
mkdir -p "$work"

echo "графика: создаю $work/program.s"
qemu-riscv32 -B 0x100000000 os/bootstrap/compiler.elf \
    os/main.saltic "$work/program.s"

echo "графика: собираю $work/program.elf"
riscv32-none-elf-gcc \
    -DSALTIC_KEEP_SCREEN \
    -march=rv32i_zicsr -mabi=ilp32 -mno-relax -nostdlib \
    -Wl,--no-relax,-T,os/target/qemu_virt/linker.ld,-Map,"$work/program.map" \
    os/target/qemu_virt/platform.S "$work/program.s" \
    -o "$work/program.elf"

echo "графика: сборка готова"

if [[ "${1:-}" == "--check" ]]; then
    stdout="$work/stdout.txt"
    status=0
    timeout 10s qemu-system-riscv32 \
        -machine virt \
        -global virtio-mmio.force-legacy=false \
        -device ramfb \
        -device virtio-keyboard-device \
        -display none \
        -serial stdio \
        -monitor none \
        -bios none \
        -kernel "$work/program.elf" \
        >"$stdout" || status=$?
    if (( status != 0 && status != 124 )); then
        exit "$status"
    fi
    cat "$stdout"
    grep -Fxq "клавиатура Saltic готова" "$stdout"
    echo "графика: QEMU-контур пройден"
fi
