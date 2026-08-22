#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cd "$root"
nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run \
    "SALTIC_BUILD_DIR='$work/checker-build' bash bootstrap/build.sh tests/checker.saltic '$work/checker.elf' && qemu-riscv32 -B 0x100000000 '$work/checker.elf' soul/core/tests/fixed.saltic >'$work/valid-diagnostics.txt' && qemu-riscv32 -B 0x100000000 '$work/checker.elf' soul/core/tests/fixed-errors.saltic >'$work/errors.txt' && SALTIC_BUILD_DIR='$work/program-build' bash bootstrap/build.sh soul/core/tests/fixed.saltic '$work/fixed.elf' && qemu-riscv32 -B 0x100000000 '$work/fixed.elf' >'$work/stdout.txt'"

test ! -s "$work/valid-diagnostics.txt"
sed -E 's/^([^|]+)\|[0-9]+\|[0-9]+\|/\1|/' \
    "$work/errors.txt" >"$work/errors-normalized.txt"
diff -u soul/core/tests/expected/fixed-errors.txt "$work/errors-normalized.txt"
diff -u soul/core/tests/expected/fixed.txt "$work/stdout.txt"

echo "фиксированные типы: нативная проверка пройдена"
