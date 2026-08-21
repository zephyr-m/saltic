#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

work=".cache/build/selfhost-parity"
heap_bytes="${SALTIC_SELFHOST_HEAP_BYTES:-536870912}"
memory_bytes="${SALTIC_SELFHOST_MEMORY_BYTES:-671088640}"
step_limit="${SALTIC_SELFHOST_STEP_LIMIT:-4000000000}"
progress_steps="${SALTIC_SELFHOST_PROGRESS_STEPS:-100000000}"

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
    local stage="$5"
    local progress=()

    if ((progress_steps > 0)); then
        progress=(
            --progress
            --progress-steps "$progress_steps"
            --progress-label "самохостинг: $stage"
            --heap-size "$heap_bytes"
        )
    fi

    node js/4-vm.js "$compiler" --memory "$memory_bytes" --steps "$step_limit" \
        "${progress[@]}" -- "$work/source/toolchain.saltic" "$assembly" \
        >"$stdout" 2> >(tee "$stderr" >&2)
}

report_compiler_failure() {
    local stage="$1"
    local status="$2"
    local directory="$3"
    local compiler="$4"
    local stderr="$5"
    local pc
    local ra
    local symbol

    echo "самохостинг: $stage завершился с кодом $status, смотри $directory/"
    if ((status == 65)); then
        echo "самохостинг: исчерпан гостевой heap ($((heap_bytes / 1024 / 1024)) МБ)"
        echo "самохостинг: увеличь SALTIC_SELFHOST_HEAP_BYTES и SALTIC_SELFHOST_MEMORY_BYTES"
    fi
    if ((status == 64)); then
        echo "самохостинг: гостевой программе не переданы обязательные аргументы"
    fi

    pc="$(sed -n 's/.*PC: \(0x[0-9a-fA-F]*\).*/\1/p' "$stderr" | tail -n 1)"
    ra="$(sed -n 's/.*RA: \(0x[0-9a-fA-F]*\).*/\1/p' "$stderr" | tail -n 1)"
    if command -v addr2line >/dev/null 2>&1; then
        if [[ -n "$pc" ]]; then
            symbol="$(addr2line -f -e "$compiler" "$pc" | head -n 1)"
            echo "самохостинг: место остановки: $symbol ($pc)"
        fi
        if [[ -n "$ra" ]]; then
            symbol="$(addr2line -f -e "$compiler" "$ra" | head -n 1)"
            echo "самохостинг: вызвано из: $symbol ($ra)"
        fi
    fi
}

echo "самохостинг: создаю корневой исходник toolchain"
node tests/compiler-parity.js build "$work/source/toolchain.saltic"
node js/1-parser.js "$work/source/toolchain.saltic" >"$work/source/ast.json"
node js/2-checker.js "$work/source/toolchain.saltic" >"$work/source/checker.json"

echo "самохостинг: этап 1 — начальная сборка через JS-компилятор"
nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run \
    "node js/3-compiler.js --assembly '$work/stage-1/toolchain-rv32i.s' '$work/source/toolchain.saltic' '$work/stage-1/toolchain-small.elf'"
assemble_stage \
    "$work/stage-1/toolchain-rv32i.s" \
    "$work/stage-1/toolchain-large-heap.s" \
    "$work/stage-1/toolchain.elf"

echo "самохостинг: этап 2 — Saltic-компилятор компилирует свой toolchain"
if run_compiler \
    "$work/stage-1/toolchain.elf" \
    "$work/stage-2/toolchain-rv32i.s" \
    "$work/stage-2/stdout.txt" \
    "$work/stage-2/stderr.txt" \
    "этап 2"; then
    :
else
    status=$?
    report_compiler_failure \
        "этап 2" "$status" "$work/stage-2" \
        "$work/stage-1/toolchain.elf" "$work/stage-2/stderr.txt"
    if grep -q 'step limit reached' "$work/stage-2/stderr.txt"; then
        echo "самохостинг: исчерпан лимит инструкций; смотри адрес остановки выше"
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
if run_compiler \
    "$work/stage-2/toolchain.elf" \
    "$work/stage-3/toolchain-rv32i.s" \
    "$work/stage-3/stdout.txt" \
    "$work/stage-3/stderr.txt" \
    "этап 3"; then
    :
else
    status=$?
    report_compiler_failure \
        "этап 3" "$status" "$work/stage-3" \
        "$work/stage-2/toolchain.elf" "$work/stage-3/stderr.txt"
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
