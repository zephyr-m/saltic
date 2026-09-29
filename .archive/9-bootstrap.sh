#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

work=".cache/build/bootstrap-parity"
heap_bytes=536870912
mkdir -p "$work/stage-1" "$work/stage-2" "$work/canonical"

command -v qemu-riscv32 >/dev/null
command -v riscv32-none-elf-gcc >/dev/null
command -v riscv32-none-elf-objcopy >/dev/null

echo "bootstrap: зафиксированный компилятор собирает toolchain"
SALTIC_BUILD_DIR="$work/stage-1" \
SALTIC_HEAP_BYTES="$heap_bytes" \
bash bootstrap/build.sh \
    soul/toolchain.saltic \
    "$work/stage-1/toolchain.elf" \
    "$work/stage-1/toolchain.s"

echo "bootstrap: сравниваю исполняемый образ с зафиксированным компилятором"
riscv32-none-elf-objcopy \
    -O binary -j .text -j .rodata \
    bootstrap/compiler.elf \
    "$work/stage-1/bootstrap.bin"
riscv32-none-elf-objcopy \
    -O binary -j .text -j .rodata \
    "$work/stage-1/toolchain.elf" \
    "$work/stage-1/toolchain.bin"
cmp "$work/stage-1/bootstrap.bin" "$work/stage-1/toolchain.bin"

echo "bootstrap: собранный toolchain повторяет себя"
SALTIC_BOOTSTRAP_COMPILER="$work/stage-1/toolchain.elf" \
SALTIC_BUILD_DIR="$work/stage-2" \
SALTIC_HEAP_BYTES="$heap_bytes" \
bash bootstrap/build.sh \
    soul/toolchain.saltic \
    "$work/stage-2/toolchain.elf" \
    "$work/stage-2/toolchain.s"

diff -u "$work/stage-1/toolchain.s" "$work/stage-2/toolchain.s"
cmp "$work/stage-1/toolchain.elf" "$work/stage-2/toolchain.elf"

echo "bootstrap: собранный toolchain компилирует канон"
SALTIC_BOOTSTRAP_COMPILER="$work/stage-2/toolchain.elf" \
SALTIC_BUILD_DIR="$work/canonical" \
bash bootstrap/build.sh \
    canonical.saltic \
    "$work/canonical/canonical.elf" \
    "$work/canonical/canonical.s"

cp tests/fixtures/input.txt "$work/canonical/input.txt"
qemu-riscv32 -B 0x100000000 "$work/canonical/canonical.elf" \
    "$work/canonical/input.txt" "$work/canonical/output.txt" \
    >"$work/canonical/stdout.txt"

diff -u tests/expected/canonical.txt "$work/canonical/stdout.txt"
test "$(<"$work/canonical/output.txt")" = "pip:0"

echo "bootstrap: ok"
