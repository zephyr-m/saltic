#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if (( $# < 2 || $# > 3 )); then
    echo "использование: bootstrap/build.sh <исходник.saltic> <результат.elf> [результат.s]" >&2
    exit 2
fi

source_path="$1"
output_path="$2"
work="${SALTIC_BUILD_DIR:-.cache/build/bootstrap}"
assembly_path="${3:-$work/program.s}"
compiler="${SALTIC_BOOTSTRAP_COMPILER:-bootstrap/compiler.elf}"
heap_bytes="${SALTIC_HEAP_BYTES:-16777216}"
link_assembly="$assembly_path"

if [[ ! -f "$compiler" ]]; then
    echo "bootstrap compiler не найден: $compiler" >&2
    exit 1
fi
if [[ ! "$heap_bytes" =~ ^[0-9]+$ ]] || (( heap_bytes < 1 )); then
    echo "неверный SALTIC_HEAP_BYTES: $heap_bytes" >&2
    exit 2
fi

mkdir -p "$work" "$(dirname "$assembly_path")" "$(dirname "$output_path")"

qemu-riscv32 -B 0x100000000 "$compiler" "$source_path" "$assembly_path"

if (( heap_bytes != 16777216 )); then
    if ! grep -q '^\.space 16777216$' "$assembly_path"; then
        echo "стандартный heap не найден в $assembly_path" >&2
        exit 1
    fi
    link_assembly="$work/program-heap.s"
    sed "s/^\.space 16777216$/.space $heap_bytes/" \
        "$assembly_path" >"$link_assembly"
fi

riscv32-none-elf-as -march=rv32i -mabi=ilp32 \
    bootstrap/linux-memory.S -o "$work/linux-memory.o"
riscv32-none-elf-as -march=rv32i -mabi=ilp32 \
    "$link_assembly" -o "$work/program.o"
riscv32-none-elf-gcc \
    -march=rv32i -mabi=ilp32 -mno-relax -nostdlib \
    -Wl,--no-relax,--section-start=.saltic_low_memory=0x1000,-Ttext=0x10000,-e,_start \
    "$work/linux-memory.o" "$work/program.o" -o "$output_path"
