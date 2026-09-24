#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

if (( $# != 4 )); then
    echo "использование: os/bootstrap/link.sh <исходник.s> <результат.elf> <рабочая папка> <heap bytes>" >&2
    exit 2
fi

assembly_path="$1"
output_path="$2"
work="$3"
heap_bytes="$4"

if [[ ! -f "$assembly_path" ]]; then
    echo "bootstrap link: assembly не найден: $assembly_path" >&2
    exit 1
fi
if [[ ! "$heap_bytes" =~ ^[0-9]+$ ]] || (( heap_bytes < 12 || heap_bytes % 8 != 0 || heap_bytes > 4294967295 )); then
    echo "bootstrap link: неверный heap: $heap_bytes" >&2
    exit 2
fi

mkdir -p "$work" "$(dirname "$output_path")"
parameter_heap_markers="$(grep -c '^\.space SALTIC_HEAP_BYTES$' "$assembly_path" || true)"

if (( parameter_heap_markers != 1 )); then
    echo "bootstrap link: ожидалось одно параметрическое объявление heap" >&2
    exit 1
fi

riscv32-none-elf-as -march=rv32i -mabi=ilp32 \
    os/bootstrap/linux-memory.S -o "$work/linux-memory.o"
riscv32-none-elf-as -march=rv32i -mabi=ilp32 \
    --defsym SALTIC_HEAP_BYTES="$heap_bytes" \
    "$assembly_path" -o "$work/program.o"
riscv32-none-elf-gcc \
    -march=rv32i -mabi=ilp32 -mno-relax -nostdlib \
    -Wl,--no-relax,--section-start=.saltic_low_memory=0x1000,-Ttext=0x10000,-e,_start \
    "$work/linux-memory.o" "$work/program.o" -o "$output_path"
