#!/usr/bin/env bash
# Первый камень: собрать программу на Saltic компилятором с полки. Время у строк
# не ставит — его ставят программы на Saltic, в журналы которых идёт вывод.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

# Первый камень: компилятор с полки по маске, без проверки свежести — её и
# перевод родного x86-64 из эталона ведёт refresh (bootstrap/names.saltic).
# shelf <конец имени> — единственный bootstrap/saltic-*-compiler-<конец имени>.
shelf() {
    local found=(bootstrap/saltic-*-compiler-"$1")
    if [[ ${#found[@]} -ne 1 || ! -f "${found[0]}" ]]; then
        return 1
    fi
    echo "${found[0]}"
}

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
    native_override="${SALTIC_NATIVE:-}"
    exec nix \
        --extra-experimental-features "nix-command flakes" \
        develop "$root" --command \
        env \
        SALTIC_BUILD_IN_DEV_SHELL=1 \
        SALTIC_BUILD_DIR="$build_dir" \
        SALTIC_BOOTSTRAP_COMPILER="$bootstrap_override" \
        SALTIC_HEAP_BYTES="$heap_override" \
        SALTIC_TARGET="$target_override" \
        SALTIC_NATIVE="$native_override" \
        bash "$root/bootstrap/build.sh" "$@"
fi

if (( $# != 2 )); then
    echo "использование: bootstrap/build.sh <исходник.saltic> <результат.elf>" >&2
    exit 2
fi

source_path="$1"
output_path="$2"
work="${SALTIC_BUILD_DIR:-.cache/build/bootstrap}"
reference="$(shelf rv64-linux)" || { echo "bootstrap: нужен ровно один saltic-*-compiler-rv64-linux" >&2; exit 1; }
compiler="${SALTIC_BOOTSTRAP_COMPILER:-$reference}"
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

mkdir -p "$work" "$(dirname "$output_path")"
rm -f "$compiler_output"

# Загрузочный компилятор с полки (канон RV64) работает своей родной x86-версией
# с той же полки: те же байты, в разы быстрее; её нет — сам, под qemu-riscv64. При SALTIC_NATIVE=0 или с другим компилятором
# (SALTIC_BOOTSTRAP_COMPILER, stage-1 и т. п.) раннер — по заголовку файла:
# RISC-V 64 (ELF64, машина 243) — под qemu-riscv64, x86-64 (ELF64) — прямо,
# RISC-V 32 (ELF32) — под qemu-riscv32.
runner=(qemu-riscv32 -B 0x100000000 "$compiler")
if [[ "${SALTIC_NATIVE:-1}" != "0" && "$compiler" == "$reference" ]] && native="$(shelf x86_64-linux)"; then
    runner=("$native")
elif [[ "$(od -An -tx1 -j18 -N1 "$compiler" | tr -d '[:space:]')" == "f3" \
    && "$(od -An -tx1 -j4 -N1 "$compiler" | tr -d '[:space:]')" == "02" ]]; then
    runner=(qemu-riscv64 -B 0x100000000 "$compiler")
elif [[ "$(od -An -tx1 -j4 -N1 "$compiler" | tr -d '[:space:]')" == "02" ]]; then
    runner=("$compiler")
fi
"${runner[@]}" "$source_path" "$compiler_output" "$heap_bytes" "$target"

magic="$(od -An -tx1 -N4 "$compiler_output" | tr -d '[:space:]')"
expected="7f454c46"
[[ "$target" == x86_64-uefi* ]] && expected="4d5a"
if [[ "${magic:0:${#expected}}" != "$expected" ]]; then
    echo "bootstrap build: компилятор не создал образ (ожидалась подпись $expected)" >&2
    exit 1
fi

mv "$compiler_output" "$output_path"
chmod +x "$output_path"
