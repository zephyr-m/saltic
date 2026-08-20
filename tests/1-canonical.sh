#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cd "$root"
node js/1-parser.js canonical.s >/dev/null
node js/2-checker.js canonical.s >/dev/null
nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc \
    --run "node js/3-compiler.js canonical.s '$work/canonical.elf'"
cp tests/fixtures/input.txt "$work/input.txt"
node js/4-vm.js "$work/canonical.elf" --root "$work" -- \
    input.txt output.txt >"$work/stdout.txt"

diff -u tests/expected/canonical.txt "$work/stdout.txt"
test "$(<"$work/output.txt")" = "pip:0"

echo "canonical: ok"
