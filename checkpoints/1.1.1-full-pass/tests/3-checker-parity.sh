#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
work=".cache/build/checker-parity"
mkdir -p "$work/ast" "$work/expected" "$work/actual" "$work/diff"

echo "сравнение чекеров: создаю $work/checker.saltic"
node tests/checker-parity.js build "$work/checker.saltic"
node js/1-parser.js "$work/checker.saltic" >/dev/null
node js/2-checker.js "$work/checker.saltic" >/dev/null
echo "сравнение чекеров: компилирую $work/checker.elf"
nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc \
    --run "node js/3-compiler.js '$work/checker.saltic' '$work/checker.elf'"

for name in canonical canonical-errors; do
    source="$name.saltic"
    (test "$name" = "canonical-errors") && source="tests/canonical-errors.saltic"
    expected="$work/expected/$name.txt"
    actual="$work/actual/$name.txt"
    difference="$work/diff/$name.diff"
    label="каноническая программа"
    (test "$name" = "canonical-errors") && label="канонический набор ошибок"
    echo "сравнение чекеров: $label"
    node tests/checker-parity.js ast "$source" >"$work/ast/$name.json"
    node tests/checker-parity.js expected "$source" >"$expected"
    node js/4-vm.js "$work/checker.elf" --steps 1000000000 -- "$source" >"$actual"
    if ! diff -u "$expected" "$actual" >"$difference"; then
        echo "сравнение чекеров: найдено расхождение, смотри $difference"
        exit 1
    fi
done

echo "сравнение чекеров: всё совпало"
