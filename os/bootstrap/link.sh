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
default_heap_bytes=16777216

if [[ ! -f "$assembly_path" ]]; then
    echo "bootstrap link: assembly не найден: $assembly_path" >&2
    exit 1
fi
if [[ ! "$heap_bytes" =~ ^[0-9]+$ ]] || (( heap_bytes < 1 || heap_bytes > 4294967295 )); then
    echo "bootstrap link: неверный heap: $heap_bytes" >&2
    exit 2
fi

mkdir -p "$work" "$(dirname "$output_path")"
link_assembly="$assembly_path"

if (( heap_bytes != default_heap_bytes )); then
    heap_markers="$(grep -c '^\.space 16777216$' "$assembly_path" || true)"
    if (( heap_markers != 1 )); then
        echo "bootstrap link: ожидался один стандартный heap, найдено: $heap_markers" >&2
        exit 1
    fi
    link_assembly="$work/program-heap.s"
    sed "s/^\.space 16777216$/.space $heap_bytes/" \
        "$assembly_path" >"$link_assembly"
fi

riscv32-none-elf-as -march=rv32i -mabi=ilp32 \
    os/bootstrap/linux-memory.S -o "$work/linux-memory.o"
riscv32-none-elf-as -march=rv32i -mabi=ilp32 \
    "$link_assembly" -o "$work/program.o"
riscv32-none-elf-gcc \
    -march=rv32i -mabi=ilp32 -mno-relax -nostdlib \
    -Wl,--no-relax,--section-start=.saltic_low_memory=0x1000,-Ttext=0x10000,-e,_start \
    "$work/linux-memory.o" "$work/program.o" -o "$output_path"
