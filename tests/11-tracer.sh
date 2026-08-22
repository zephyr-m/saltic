#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cd "$root"
nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc \
    --run "SALTIC_BUILD_DIR='$work/build' bash bootstrap/build.sh tests/tracer.saltic '$work/target.elf' '$work/target.s' && SALTIC_HEAP_BYTES=536870912 SALTIC_BUILD_DIR='$work/build' bash bootstrap/build.sh s2/craft/tracer.saltic '$work/tracer.elf' '$work/tracer.s' && qemu-riscv32 -B 0x100000000 '$work/tracer.elf' '$work/target.elf' >'$work/stdout.txt'"
sed -E \
    -e "s|$work/target.elf|<target.elf>|" \
    -e 's/0x[0-9a-f]{8} \(("[^"]*"|группа|объект)\)/<адрес> (\1)/g' \
    "$work/stdout.txt" >"$work/normalized.txt"
diff -u tests/expected/tracer.txt "$work/normalized.txt"

echo "трассер: ок"
