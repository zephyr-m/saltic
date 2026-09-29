#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cd "$root"
nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc \
    --run "bash bootstrap/build.sh tests/diagnostics.saltic '$work/diagnostics.elf' && qemu-riscv32 -B 0x100000000 '$work/diagnostics.elf' >'$work/stdout.txt'"
diff -u tests/expected/diagnostics.txt "$work/stdout.txt"

echo "диагностика: всё согласовано"
