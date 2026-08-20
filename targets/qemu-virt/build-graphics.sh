#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

work=".cache/build/qemu-graphics"
mkdir -p "$work"

combined="$work/program-combined.s"
cp targets/qemu-virt/fw-cfg.s "$combined"
sed '/^use core$/d' targets/qemu-virt/uart.s >>"$combined"
sed '/^use core$/d' targets/qemu-virt/framebuffer.s >>"$combined"
sed '/^use core$/d' lib/graphics.s >>"$combined"
sed '/^use core$/d' lib/font.s >>"$combined"
sed '/^use core$/d' targets/qemu-virt/virtio-mmio.s >>"$combined"
sed '/^use core$/d' targets/qemu-virt/keyboard.s >>"$combined"
sed '/^use core$/d' lib/keymap-us.s >>"$combined"
sed '/^use core$/d' lib/text-field.s >>"$combined"
sed '/^use core$/d' examples/qemu-graphics.s >>"$combined"

echo "графика: проверяю объединённый Saltic-файл"
node js/1-parser.js "$combined" >/dev/null
node js/2-checker.js "$combined" >/dev/null

echo "графика: создаю $work/program.s"
node js/3-compiler.js --assembly "$work/program.s" \
    "$combined" "$work/program-vm.elf"

echo "графика: собираю $work/program.elf"
riscv32-none-elf-gcc \
    -DSALTIC_KEEP_SCREEN \
    -march=rv32i_zicsr -mabi=ilp32 -mno-relax -nostdlib \
    -Wl,--no-relax,-T,targets/qemu-virt/linker.ld,-Map,"$work/program.map" \
    targets/qemu-virt/platform.S "$work/program.s" \
    -o "$work/program.elf"

echo "графика: сборка готова"
