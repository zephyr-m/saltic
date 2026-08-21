#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
work=".cache/build/compiler-parity"
mkdir -p "$work/bootstrap" "$work/expected" "$work/actual" "$work/diff" "$work/run-host" "$work/run-saltic"

echo "сравнение компиляторов: проверяю интерфейс"
if ! grep -q '^skill compiler_compile(ast)' s2/compiler.saltic; then
    echo "сравнение компиляторов: в s2/compiler.saltic ещё нет skill compiler_compile(ast)"
    exit 1
fi

echo "сравнение компиляторов: создаю $work/bootstrap/compiler.saltic"
node tests/compiler-parity.js build "$work/bootstrap/compiler.saltic"
node js/1-parser.js "$work/bootstrap/compiler.saltic" >/dev/null
node js/2-checker.js "$work/bootstrap/compiler.saltic" >/dev/null

echo "сравнение компиляторов: собираю self-hosted compiler"
nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run \
    "node js/3-compiler.js --assembly '$work/bootstrap/compiler-rv32i.s' '$work/bootstrap/compiler.saltic' '$work/bootstrap/compiler-small.elf'"
node tests/compiler-parity.js expand-heap \
    "$work/bootstrap/compiler-rv32i.s" "$work/bootstrap/compiler-large-heap.s"
nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run \
    "riscv32-none-elf-gcc -march=rv32i -mabi=ilp32 -mno-relax -nostdlib -Wl,--no-relax,-Ttext=0x10000,-e,_start '$work/bootstrap/compiler-large-heap.s' -o '$work/bootstrap/compiler.elf'"

echo "сравнение компиляторов: получаю эталонный assembly"
nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run \
    "node js/3-compiler.js --assembly '$work/expected/canonical.s' canonical.saltic '$work/expected/canonical.elf'"

echo "сравнение компиляторов: запускаю Saltic-компилятор"
node js/4-vm.js "$work/bootstrap/compiler.elf" --steps 1000000000 -- \
    canonical.saltic "$work/actual/canonical.s"

if ! diff -u \
    -I '^  lw a0, 0(sp)$' \
    -I '^  addi a1, sp, 4$' \
    "$work/expected/canonical.s" "$work/actual/canonical.s" \
    >"$work/diff/assembly.diff"; then
    echo "сравнение компиляторов: assembly различается, смотри $work/diff/assembly.diff"
    exit 1
fi

echo "сравнение компиляторов: собираю полученный assembly"
nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run \
    "riscv32-none-elf-gcc -march=rv32i -mabi=ilp32 -mno-relax -nostdlib -Wl,--no-relax,-Ttext=0x10000,-e,_start '$work/actual/canonical.s' -o '$work/actual/canonical.elf'"

cp tests/fixtures/input.txt "$work/run-host/input.txt"
cp tests/fixtures/input.txt "$work/run-saltic/input.txt"

echo "сравнение компиляторов: запускаю оба ELF"
node js/4-vm.js "$work/expected/canonical.elf" --root "$work/run-host" -- \
    input.txt output.txt >"$work/run-host/stdout.txt"
node js/4-vm.js "$work/actual/canonical.elf" --root "$work/run-saltic" -- \
    input.txt output.txt >"$work/run-saltic/stdout.txt"

if ! diff -u "$work/run-host/stdout.txt" "$work/run-saltic/stdout.txt" >"$work/diff/stdout.diff"; then
    echo "сравнение компиляторов: stdout различается, смотри $work/diff/stdout.diff"
    exit 1
fi
if ! diff -u "$work/run-host/output.txt" "$work/run-saltic/output.txt" >"$work/diff/output.diff"; then
    echo "сравнение компиляторов: выходные файлы различаются, смотри $work/diff/output.diff"
    exit 1
fi

echo "сравнение компиляторов: всё совпало"
