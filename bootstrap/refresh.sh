#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
source bootstrap/names.sh

if ! command -v qemu-riscv32 >/dev/null 2>&1; then
    if [[ "${SALTIC_BOOTSTRAP_REFRESH_IN_DEV_SHELL:-}" == "1" ]]; then
        echo "bootstrap refresh: qemu-riscv32 отсутствует внутри проектного Nix shell" >&2
        exit 1
    fi
    if ! command -v nix >/dev/null 2>&1; then
        echo "bootstrap refresh: не найдены ни qemu-riscv32, ни nix" >&2
        exit 1
    fi

    echo "bootstrap refresh: вхожу в проектный Nix shell"
    bootstrap_override="${SALTIC_BOOTSTRAP_COMPILER:-}"
    refresh_work="${SALTIC_BOOTSTRAP_REFRESH_DIR:-}"
    refresh_heap="${SALTIC_BOOTSTRAP_REFRESH_HEAP_BYTES:-}"
    exec nix \
        --extra-experimental-features "nix-command flakes" \
        develop "$root" --command \
        env \
        SALTIC_BOOTSTRAP_REFRESH_IN_DEV_SHELL=1 \
        SALTIC_BOOTSTRAP_COMPILER="$bootstrap_override" \
        SALTIC_BOOTSTRAP_REFRESH_DIR="$refresh_work" \
        SALTIC_BOOTSTRAP_REFRESH_HEAP_BYTES="$refresh_heap" \
        bash "$root/bootstrap/refresh.sh" "$@"
fi

work="${SALTIC_BOOTSTRAP_REFRESH_DIR:-.cache/build/bootstrap-refresh}"
heap_bytes="${SALTIC_BOOTSTRAP_REFRESH_HEAP_BYTES:-4026531840}"
source_path="${1:-soul/seed/toolchain.saltic}"

mkdir -p "$work/stage-1" "$work/stage-2" "$work/stage-3"

bootstrap_compiler="${SALTIC_BOOTSTRAP_COMPILER:-$(saltic_bootstrap_compiler)}"
mkdir -p "$work/previous"
rm -f "$work/previous/"*
previous="$work/previous/$(basename "$bootstrap_compiler")"
cp "$bootstrap_compiler" "$previous"

echo "bootstrap refresh: исходный compiler $bootstrap_compiler"

echo "bootstrap refresh: текущее поколение собирает прямой ELF stage-1"
SALTIC_BOOTSTRAP_COMPILER="$bootstrap_compiler" \
SALTIC_BUILD_DIR="$work/stage-1" \
SALTIC_HEAP_BYTES="$heap_bytes" \
SALTIC_DIRECT_ONLY=1 \
bash bootstrap/build.sh \
    "$source_path" \
    "$work/stage-1/toolchain.elf" \
    "$work/stage-1/toolchain.s"

echo "bootstrap refresh: stage-1 собирает stage-2"
SALTIC_BOOTSTRAP_COMPILER="$work/stage-1/toolchain.elf" \
SALTIC_BUILD_DIR="$work/stage-2" \
SALTIC_HEAP_BYTES="$heap_bytes" \
SALTIC_DIRECT_ONLY=1 \
bash bootstrap/build.sh \
    "$source_path" \
    "$work/stage-2/toolchain.elf" \
    "$work/stage-2/toolchain.s"

echo "bootstrap refresh: stage-2 собирает stage-3"
SALTIC_BOOTSTRAP_COMPILER="$work/stage-2/toolchain.elf" \
SALTIC_BUILD_DIR="$work/stage-3" \
SALTIC_HEAP_BYTES="$heap_bytes" \
SALTIC_DIRECT_ONLY=1 \
bash bootstrap/build.sh \
    "$source_path" \
    "$work/stage-3/toolchain.elf" \
    "$work/stage-3/toolchain.s"

echo "bootstrap refresh: проверяю fixed point"
test ! -e "$work/stage-1/toolchain.s"
test ! -e "$work/stage-2/toolchain.s"
test ! -e "$work/stage-3/toolchain.s"
cmp "$work/stage-2/toolchain.elf" "$work/stage-3/toolchain.elf"

compiler="$(saltic_compiler_path rv32i linux .elf)"
if cmp -s "$work/stage-3/toolchain.elf" "$compiler" && [[ -f "${compiler%.elf}.txt" ]]; then
    echo "bootstrap refresh: $(basename "$compiler") не изменился"
else
    # Прежняя версия того же компилятора больше не нужна: новая заменяет её.
    for old in bootstrap/saltic-*-compiler-rv32i-linux.elf; do
        if [[ -f "$old" && "$old" != "$compiler" ]]; then rm -f "$old" "${old%.elf}.txt"; fi
    done
    cp "$work/stage-3/toolchain.elf" "$compiler"
    chmod +x "$compiler"
    saltic_write_passport "$compiler" "rv32i, linux (qemu-riscv32 -B 0x100000000)" "rv32i, x86_64" \
        "$previous" "$heap_bytes" "сходится (stage-2 = stage-3)"
    echo "bootstrap refresh: $(basename "$compiler") обновлён"
fi
sha256sum "$compiler"

native="$(saltic_native_compiler)"
echo "bootstrap refresh: $(basename "$native") готов"
qemu_virt="$(saltic_qemu_virt_compiler)"
echo "bootstrap refresh: $(basename "$qemu_virt") готов"
