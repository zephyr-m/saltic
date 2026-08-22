#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

work=".cache/build/qemu-graphics"
mkdir -p "$work"

combined="$work/program-combined.saltic"
cp targets/qemu-virt/fw-cfg.saltic "$combined"
sed '/^use core$/d' targets/qemu-virt/uart.saltic >>"$combined"
sed '/^use core$/d' targets/qemu-virt/framebuffer.saltic >>"$combined"
sed '/^use core$/d' s2/engine/graphics.saltic >>"$combined"
sed '/^use core$/d' s2/engine/font.saltic >>"$combined"
sed '/^use core$/d' targets/qemu-virt/virtio-mmio.saltic >>"$combined"
sed '/^use core$/d' targets/qemu-virt/keyboard.saltic >>"$combined"
sed '/^use core$/d' s2/engine/keymap_us.saltic >>"$combined"
sed '/^use core$/d' s2/engine/text_field.saltic >>"$combined"
sed '/^use core$/d' examples/qemu-graphics.saltic >>"$combined"

echo "графика: создаю $work/program.s"
qemu-riscv32 -B 0x100000000 bootstrap/compiler.elf \
    "$combined" "$work/program.s"

echo "графика: собираю $work/program.elf"
riscv32-none-elf-gcc \
    -DSALTIC_KEEP_SCREEN \
    -march=rv32i_zicsr -mabi=ilp32 -mno-relax -nostdlib \
    -Wl,--no-relax,-T,targets/qemu-virt/linker.ld,-Map,"$work/program.map" \
    targets/qemu-virt/platform.S "$work/program.s" \
    -o "$work/program.elf"

echo "графика: сборка готова"
