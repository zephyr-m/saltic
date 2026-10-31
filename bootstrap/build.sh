#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
source bootstrap/names.sh

if ! command -v qemu-riscv32 >/dev/null 2>&1; then
    if [[ "${SALTIC_BUILD_IN_DEV_SHELL:-}" == "1" ]]; then
        echo "bootstrap build: qemu-riscv32 отсутствует внутри проектного Nix shell" >&2
        exit 1
    fi
    if ! command -v nix >/dev/null 2>&1; then
        echo "bootstrap build: не найдены ни qemu-riscv32, ни nix" >&2
        exit 1
    fi

    echo "bootstrap build: вхожу в проектный Nix shell"
    build_dir="${SALTIC_BUILD_DIR:-}"
    bootstrap_override="${SALTIC_BOOTSTRAP_COMPILER:-}"
    heap_override="${SALTIC_HEAP_BYTES:-}"
    target_override="${SALTIC_TARGET:-}"
    exec nix \
        --extra-experimental-features "nix-command flakes" \
        develop "$root" --command \
        env \
        SALTIC_BUILD_IN_DEV_SHELL=1 \
        SALTIC_BUILD_DIR="$build_dir" \
        SALTIC_BOOTSTRAP_COMPILER="$bootstrap_override" \
        SALTIC_HEAP_BYTES="$heap_override" \
        SALTIC_TARGET="$target_override" \
        bash "$root/bootstrap/build.sh" "$@"
fi

if (( $# < 2 || $# > 3 )); then
    echo "использование: bootstrap/build.sh <исходник.saltic> <результат.elf> [результат.s]" >&2
    exit 2
fi

source_path="$1"
output_path="$2"
work="${SALTIC_BUILD_DIR:-.cache/build/bootstrap}"
assembly_path="${3:-$work/program.s}"
compiler="${SALTIC_BOOTSTRAP_COMPILER:-$(saltic_bootstrap_compiler)}"
heap_bytes="${SALTIC_HEAP_BYTES:-536870912}"
target="${SALTIC_TARGET:-rv32i}"
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
    "$compiler" "$source_path" "$compiler_output" "$heap_bytes" "$target"

magic="$(od -An -tx1 -N4 "$compiler_output" | tr -d '[:space:]')"
if [[ "$magic" != "7f454c46" ]]; then
    echo "bootstrap build: компилятор не создал прямой ELF" >&2
    exit 1
fi

mv "$compiler_output" "$output_path"
chmod +x "$output_path"
