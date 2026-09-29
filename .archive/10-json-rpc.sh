#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cd "$root"
nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc \
    --run "bash bootstrap/build.sh tests/json-rpc.saltic '$work/json-rpc.elf' && qemu-riscv32 -B 0x100000000 '$work/json-rpc.elf' >'$work/stdout.txt'"
diff -u tests/expected/json-rpc.txt "$work/stdout.txt"

echo "json-rpc: ok"
