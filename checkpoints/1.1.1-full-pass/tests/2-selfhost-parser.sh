#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cd "$root"
nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc \
    --run "node js/3-compiler.js s2/parser.saltic '$work/parser.elf'"
node js/4-vm.js "$work/parser.elf" --steps 1000000000 -- canonical.saltic \
    >"$work/stdout.txt"

diff -u tests/expected/selfhost-parser.txt "$work/stdout.txt"

echo "selfhost-parser: ok"
