#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cd "$root"
nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc \
    --run "bash bootstrap/build.sh soul/core/tests/contract.saltic '$work/core-contract.elf' && qemu-riscv32 -B 0x100000000 '$work/core-contract.elf' >'$work/stdout.txt'"
diff -u soul/core/tests/expected/contract.txt "$work/stdout.txt"

echo "core: единый контракт подтверждён"
