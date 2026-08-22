#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cd "$root"
nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run \
    "riscv32-none-elf-gcc -march=rv32i -mabi=ilp32 -mno-relax -nostdlib -Wl,--no-relax,-Ttext=0x10000,-e,_start tests/fixtures/vm-canonical.S -o '$work/vm-canonical.elf' && riscv32-none-elf-objcopy -O binary '$work/vm-canonical.elf' '$work/vm-canonical.bin' && SALTIC_HEAP_BYTES=536870912 SALTIC_BUILD_DIR='$work/build' bash bootstrap/build.sh tests/vm.saltic '$work/vm.elf' && qemu-riscv32 -B 0x100000000 '$work/vm.elf' '$work/vm-canonical.elf' '$work/vm-canonical.bin' tests/fixtures/input.txt '$work/actual.txt'"

diff -u tests/expected/vm.txt "$work/actual.txt"

echo "VM: нативная проверка пройдена"
