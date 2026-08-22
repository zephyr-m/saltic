#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root"

work="${SALTIC_QEMU_GRAPHICS_DIR:-.cache/build/qemu-graphics}"
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
    qemu-system-riscv32 \
        -machine virt \
        -global virtio-mmio.force-legacy=false \
        -device ramfb \
        -device virtio-keyboard-device \
        -display none \
        -serial stdio \
        -monitor none \
        -bios none \
        -kernel "$work/program.elf" \
        >"$stdout" &
    qemu_pid=$!

    stop_qemu() {
        if kill -0 "$qemu_pid" 2>/dev/null; then
            kill "$qemu_pid" 2>/dev/null || true
        fi
        wait "$qemu_pid" 2>/dev/null || true
    }
    trap stop_qemu EXIT

    ready=0
    for (( attempt = 0; attempt < 600; attempt++ )); do
        if grep -Fxq "клавиатура Saltic готова" "$stdout"; then
            ready=1
            break
        fi
        if ! kill -0 "$qemu_pid" 2>/dev/null; then
            break
        fi
        sleep 0.1
    done

    stop_qemu
    trap - EXIT
    cat "$stdout"
    if (( ready == 0 )); then
        echo "графика: QEMU не сообщил о готовности за 60 секунд" >&2
        exit 1
    fi
    echo "графика: QEMU-контур пройден"
fi
