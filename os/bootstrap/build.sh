#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

if (( $# < 2 || $# > 3 )); then
    echo "использование: os/bootstrap/build.sh <исходник.saltic> <результат.elf> [результат.s]" >&2
    exit 2
fi

source_path="$1"
output_path="$2"
work="${SALTIC_BUILD_DIR:-.cache/build/bootstrap}"
assembly_path="${3:-$work/program.s}"
compiler="${SALTIC_BOOTSTRAP_COMPILER:-os/bootstrap/compiler.elf}"
heap_bytes="${SALTIC_HEAP_BYTES:-536870912}"
direct_only="${SALTIC_DIRECT_ONLY:-0}"
compiler_output="$work/compiler-output"

if [[ ! -f "$compiler" ]]; then
    echo "bootstrap compiler не найден: $compiler" >&2
    exit 1
fi
if [[ ! "$heap_bytes" =~ ^[0-9]+$ ]] || (( heap_bytes < 12 || heap_bytes % 8 != 0 )); then
    echo "неверный SALTIC_HEAP_BYTES: $heap_bytes" >&2
    exit 2
fi

mkdir -p "$work" "$(dirname "$output_path")" "$(dirname "$assembly_path")"
rm -f "$compiler_output" "$assembly_path"

qemu-riscv32 -B 0x100000000 \
    "$compiler" "$source_path" "$compiler_output" "$heap_bytes"

magic="$(od -An -tx1 -N4 "$compiler_output" | tr -d '[:space:]')"
if [[ "$magic" == "7f454c46" ]]; then
    mv "$compiler_output" "$output_path"
    chmod +x "$output_path"
    exit 0
fi

if [[ "$direct_only" == "1" ]]; then
    echo "bootstrap build: компилятор не создал прямой ELF" >&2
    exit 1
fi

mv "$compiler_output" "$assembly_path"
bash os/bootstrap/link.sh "$assembly_path" "$output_path" "$work" "$heap_bytes"
