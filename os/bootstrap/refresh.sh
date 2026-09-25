#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

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
        bash "$root/os/bootstrap/refresh.sh" "$@"
fi

work="${SALTIC_BOOTSTRAP_REFRESH_DIR:-.cache/build/bootstrap-refresh}"
heap_bytes="${SALTIC_BOOTSTRAP_REFRESH_HEAP_BYTES:-4026531840}"
source_path="${1:-soul/seed/toolchain.saltic}"

mkdir -p "$work/stage-1" "$work/stage-2" "$work/stage-3"

bootstrap_compiler="${SALTIC_BOOTSTRAP_COMPILER:-os/bootstrap/compiler.elf}"

echo "bootstrap refresh: исходный compiler $bootstrap_compiler"

echo "bootstrap refresh: текущее поколение собирает прямой ELF stage-1"
SALTIC_BOOTSTRAP_COMPILER="$bootstrap_compiler" \
SALTIC_BUILD_DIR="$work/stage-1" \
SALTIC_HEAP_BYTES="$heap_bytes" \
SALTIC_DIRECT_ONLY=1 \
bash os/bootstrap/build.sh \
    "$source_path" \
    "$work/stage-1/toolchain.elf" \
    "$work/stage-1/toolchain.s"

echo "bootstrap refresh: stage-1 собирает stage-2"
SALTIC_BOOTSTRAP_COMPILER="$work/stage-1/toolchain.elf" \
SALTIC_BUILD_DIR="$work/stage-2" \
SALTIC_HEAP_BYTES="$heap_bytes" \
SALTIC_DIRECT_ONLY=1 \
bash os/bootstrap/build.sh \
    "$source_path" \
    "$work/stage-2/toolchain.elf" \
    "$work/stage-2/toolchain.s"

echo "bootstrap refresh: stage-2 собирает stage-3"
SALTIC_BOOTSTRAP_COMPILER="$work/stage-2/toolchain.elf" \
SALTIC_BUILD_DIR="$work/stage-3" \
SALTIC_HEAP_BYTES="$heap_bytes" \
SALTIC_DIRECT_ONLY=1 \
bash os/bootstrap/build.sh \
    "$source_path" \
    "$work/stage-3/toolchain.elf" \
    "$work/stage-3/toolchain.s"

echo "bootstrap refresh: проверяю fixed point"
test ! -e "$work/stage-1/toolchain.s"
test ! -e "$work/stage-2/toolchain.s"
test ! -e "$work/stage-3/toolchain.s"
cmp "$work/stage-2/toolchain.elf" "$work/stage-3/toolchain.elf"

cp "$work/stage-3/toolchain.elf" os/bootstrap/compiler.elf

echo "bootstrap refresh: compiler.elf обновлён"
sha256sum os/bootstrap/compiler.elf
