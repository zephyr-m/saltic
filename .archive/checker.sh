#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cd "$root"
nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run \
    "SALTIC_BUILD_DIR='$work/build' bash bootstrap/build.sh tests/checker.saltic '$work/checker.elf' && qemu-riscv32 -B 0x100000000 '$work/checker.elf' canonical.saltic >'$work/canonical.txt' && qemu-riscv32 -B 0x100000000 '$work/checker.elf' tests/canonical-errors.saltic >'$work/errors.txt'"

test ! -s "$work/canonical.txt"
diff -u tests/expected/checker-errors.txt "$work/errors.txt"

echo "чекер: нативная проверка пройдена"
