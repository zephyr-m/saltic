#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cd "$root"
nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run \
    "SALTIC_BUILD_DIR='$work/checker-build' bash bootstrap/build.sh tests/checker.saltic '$work/checker.elf' && qemu-riscv32 -B 0x100000000 '$work/checker.elf' tests/fixtures/modules/main.saltic >'$work/main-diagnostics.txt' && qemu-riscv32 -B 0x100000000 '$work/checker.elf' tests/fixtures/modules/errors.saltic >'$work/errors.txt' && SALTIC_BUILD_DIR='$work/program-build' bash bootstrap/build.sh tests/fixtures/modules/main.saltic '$work/modules.elf' && qemu-riscv32 -B 0x100000000 '$work/modules.elf' >'$work/stdout.txt'"

test ! -s "$work/main-diagnostics.txt"
diff -u tests/expected/module-errors.txt "$work/errors.txt"
diff -u tests/expected/modules.txt "$work/stdout.txt"

echo "модули: нативная проверка пройдена"
