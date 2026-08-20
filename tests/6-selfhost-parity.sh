#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

work=".cache/build/selfhost-parity"
heap_bytes="${SALTIC_SELFHOST_HEAP_BYTES:-50331648}"
memory_bytes="${SALTIC_SELFHOST_MEMORY_BYTES:-67108864}"
step_limit="${SALTIC_SELFHOST_STEP_LIMIT:-1000000000}"

mkdir -p "$work/source" "$work/stage-1" "$work/stage-2" "$work/stage-3" "$work/diff"

assemble_stage() {
    local input="$1"
    local expanded="$2"
    local output="$3"

    sed "s/\.space 16777216/.space $heap_bytes/" "$input" >"$expanded"
    nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run \
        "riscv32-none-elf-gcc -march=rv32i -mabi=ilp32 -mno-relax -nostdlib -Wl,--no-relax,-Ttext=0x10000,-e,_start '$expanded' -o '$output'"
}

run_compiler() {
    local compiler="$1"
    local assembly="$2"
    local stdout="$3"
    local stderr="$4"

    node js/4-vm.js "$compiler" --memory "$memory_bytes" --steps "$step_limit" -- \
        "$work/source/toolchain.s" "$assembly" >"$stdout" 2>"$stderr"
}

echo "самохостинг: создаю единый исходник toolchain"
node tests/compiler-parity.js build "$work/source/toolchain.s"
node js/1-parser.js "$work/source/toolchain.s" >"$work/source/ast.json"
node js/2-checker.js "$work/source/toolchain.s" >"$work/source/checker.json"

echo "самохостинг: этап 1 — начальная сборка через JS-компилятор"
nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run \
    "node js/3-compiler.js --assembly '$work/stage-1/toolchain-rv32i.s' '$work/source/toolchain.s' '$work/stage-1/toolchain-small.elf'"
assemble_stage \
    "$work/stage-1/toolchain-rv32i.s" \
    "$work/stage-1/toolchain-large-heap.s" \
    "$work/stage-1/toolchain.elf"

echo "самохостинг: этап 2 — Saltic-компилятор компилирует свой toolchain"
if ! run_compiler \
    "$work/stage-1/toolchain.elf" \
    "$work/stage-2/toolchain-rv32i.s" \
    "$work/stage-2/stdout.txt" \
    "$work/stage-2/stderr.txt"; then
    echo "самохостинг: этап 2 завершился ошибкой, смотри $work/stage-2/"
    (test -s "$work/stage-2/stderr.txt") && sed 's/^/самохостинг: /' "$work/stage-2/stderr.txt"
    if grep -q 'step limit reached' "$work/stage-2/stderr.txt"; then
        echo "самохостинг: исчерпан лимит инструкций; текущие группы и lexer требуют оптимизации"
    fi
    exit 1
fi

if ! diff -u \
    "$work/stage-1/toolchain-rv32i.s" \
    "$work/stage-2/toolchain-rv32i.s" \
    >"$work/diff/stage-1--stage-2.diff"; then
    echo "самохостинг: этапы 1 и 2 различаются, смотри $work/diff/stage-1--stage-2.diff"
    exit 1
fi

echo "самохостинг: собираю этап 2"
assemble_stage \
    "$work/stage-2/toolchain-rv32i.s" \
    "$work/stage-2/toolchain-large-heap.s" \
    "$work/stage-2/toolchain.elf"

echo "самохостинг: этап 3 — самособранный компилятор повторяет сборку"
if ! run_compiler \
    "$work/stage-2/toolchain.elf" \
    "$work/stage-3/toolchain-rv32i.s" \
    "$work/stage-3/stdout.txt" \
    "$work/stage-3/stderr.txt"; then
    echo "самохостинг: этап 3 завершился ошибкой, смотри $work/stage-3/"
    (test -s "$work/stage-3/stderr.txt") && sed 's/^/самохостинг: /' "$work/stage-3/stderr.txt"
    exit 1
fi

if ! diff -u \
    "$work/stage-2/toolchain-rv32i.s" \
    "$work/stage-3/toolchain-rv32i.s" \
    >"$work/diff/stage-2--stage-3.diff"; then
    echo "самохостинг: этапы 2 и 3 различаются, смотри $work/diff/stage-2--stage-3.diff"
    exit 1
fi

echo "самохостинг: toolchain достиг стабильной self-hosted сборки"
