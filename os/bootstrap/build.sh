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

if [[ ! -f "$compiler" ]]; then
    echo "bootstrap compiler не найден: $compiler" >&2
    exit 1
fi
if [[ ! "$heap_bytes" =~ ^[0-9]+$ ]] || (( heap_bytes < 1 )); then
    echo "неверный SALTIC_HEAP_BYTES: $heap_bytes" >&2
    exit 2
fi

mkdir -p "$work" "$(dirname "$assembly_path")"

qemu-riscv32 -B 0x100000000 "$compiler" "$source_path" "$assembly_path"

bash os/bootstrap/link.sh \
    "$assembly_path" \
    "$output_path" \
    "$work" \
    "$heap_bytes"
