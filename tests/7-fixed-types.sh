#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

work=".cache/build/fixed-types"
mkdir -p "$work/ast" "$work/checker" "$work/compiler" "$work/bootstrap" "$work/run" "$work/diff"

echo "фиксированные типы: разбираю рабочую программу"
node js/1-parser.js tests/fixed-types.saltic >"$work/ast/fixed-types.json"
echo "фиксированные типы: проверяю рабочую программу"
node js/2-checker.js tests/fixed-types.saltic >"$work/checker/fixed-types.json"

echo "фиксированные типы: разбираю программу ошибок"
node js/1-parser.js tests/fixed-types-errors.saltic >"$work/ast/fixed-types-errors.json"
echo "фиксированные типы: сохраняю диагностику программы ошибок"
node tests/checker-parity.js expected tests/fixed-types-errors.saltic \
    >"$work/checker/fixed-types-errors.txt"
sed -E 's/^([^|]+)\|[0-9]+\|[0-9]+\|/\1|/' \
    "$work/checker/fixed-types-errors.txt" \
    >"$work/checker/fixed-types-errors-normalized.txt"
if ! diff -u tests/expected/fixed-types-errors.txt \
    "$work/checker/fixed-types-errors-normalized.txt" \
    >"$work/diff/fixed-types-errors.diff"; then
    echo "фиксированные типы: диагностика различается, смотри $work/diff/fixed-types-errors.diff"
    exit 1
fi

echo "фиксированные типы: собираю Saltic-чекер"
node tests/checker-parity.js build "$work/bootstrap/checker.saltic"
nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run \
    "node js/3-compiler.js '$work/bootstrap/checker.saltic' '$work/bootstrap/checker.elf'"
node js/4-vm.js "$work/bootstrap/checker.elf" --steps 1000000000 -- \
    tests/fixed-types.saltic >"$work/checker/saltic-valid.txt"
test ! -s "$work/checker/saltic-valid.txt"
node js/4-vm.js "$work/bootstrap/checker.elf" --steps 1000000000 -- \
    tests/fixed-types-errors.saltic >"$work/checker/saltic-errors.txt"
if ! diff -u "$work/checker/fixed-types-errors.txt" \
    "$work/checker/saltic-errors.txt" >"$work/diff/checkers.diff"; then
    echo "фиксированные типы: чекеры различаются, смотри $work/diff/checkers.diff"
    exit 1
fi

echo "фиксированные типы: компилирую рабочую программу"
nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run \
    "node js/3-compiler.js --assembly '$work/compiler/js.s' tests/fixed-types.saltic '$work/compiler/js.elf'"

echo "фиксированные типы: собираю Saltic-компилятор"
node tests/compiler-parity.js build "$work/bootstrap/compiler.saltic"
nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run \
    "node js/3-compiler.js --assembly '$work/bootstrap/compiler-small.s' '$work/bootstrap/compiler.saltic' '$work/bootstrap/compiler-small.elf'"
node tests/compiler-parity.js expand-heap \
    "$work/bootstrap/compiler-small.s" "$work/bootstrap/compiler-large.s"
nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run \
    "riscv32-none-elf-gcc -march=rv32i -mabi=ilp32 -mno-relax -nostdlib -Wl,--no-relax,-Ttext=0x10000,-e,_start '$work/bootstrap/compiler-large.s' -o '$work/bootstrap/compiler.elf'"
node js/4-vm.js "$work/bootstrap/compiler.elf" --steps 1000000000 -- \
    tests/fixed-types.saltic "$work/compiler/saltic.s"
if ! diff -u "$work/compiler/js.s" "$work/compiler/saltic.s" \
    >"$work/diff/compilers.diff"; then
    echo "фиксированные типы: компиляторы различаются, смотри $work/diff/compilers.diff"
    exit 1
fi
nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run \
    "riscv32-none-elf-gcc -march=rv32i -mabi=ilp32 -mno-relax -nostdlib -Wl,--no-relax,-Ttext=0x10000,-e,_start '$work/compiler/saltic.s' -o '$work/compiler/saltic.elf'"

echo "фиксированные типы: запускаю рабочую программу"
node js/4-vm.js "$work/compiler/js.elf" >"$work/run/js.txt"
node js/4-vm.js "$work/compiler/saltic.elf" >"$work/run/saltic.txt"
if ! diff -u "$work/run/js.txt" "$work/run/saltic.txt" >"$work/diff/runtime.diff"; then
    echo "фиксированные типы: выполнение различается, смотри $work/diff/runtime.diff"
    exit 1
fi
if ! diff -u tests/expected/fixed-types.txt "$work/run/js.txt" \
    >"$work/diff/stdout.diff"; then
    echo "фиксированные типы: вывод различается, смотри $work/diff/stdout.diff"
    exit 1
fi

echo "фиксированные типы: всё совпало"
