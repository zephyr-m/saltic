#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

work="${SALTIC_BOOTSTRAP_REFRESH_DIR:-.cache/build/bootstrap-refresh}"
heap_bytes="${SALTIC_BOOTSTRAP_REFRESH_HEAP_BYTES:-536870912}"
source_path="${1:-soul/seed/toolchain.saltic}"

mkdir -p "$work/stage-1" "$work/stage-2" "$work/stage-3"

bootstrap_compiler="${SALTIC_BOOTSTRAP_COMPILER:-os/bootstrap/compiler.elf}"
if grep -a -q 'core\.group\.count' "$bootstrap_compiler"; then
    mkdir -p "$work/seed-transition"
    transition_compiler="$work/seed-transition/compiler.elf"
    cp "$bootstrap_compiler" "$transition_compiler"
    LC_ALL=C perl -0pi -e 's/core/seed/g' "$transition_compiler"
    if ! grep -a -q 'seed\.group\.count' "$transition_compiler"; then
        echo "bootstrap refresh: не удалось подготовить переход core → seed" >&2
        exit 1
    fi
    bootstrap_compiler="$transition_compiler"
    echo "bootstrap refresh: подготовлен одноразовый переход core → seed"
fi

echo "bootstrap refresh: текущее поколение собирает stage-1"
SALTIC_BOOTSTRAP_COMPILER="$bootstrap_compiler" \
SALTIC_BUILD_DIR="$work/stage-1" \
SALTIC_HEAP_BYTES="$heap_bytes" \
bash os/bootstrap/build.sh \
    "$source_path" \
    "$work/stage-1/toolchain.elf" \
    "$work/stage-1/toolchain.s"

echo "bootstrap refresh: stage-1 собирает stage-2"
SALTIC_BOOTSTRAP_COMPILER="$work/stage-1/toolchain.elf" \
SALTIC_BUILD_DIR="$work/stage-2" \
SALTIC_HEAP_BYTES="$heap_bytes" \
bash os/bootstrap/build.sh \
    "$source_path" \
    "$work/stage-2/toolchain.elf" \
    "$work/stage-2/toolchain.s"

echo "bootstrap refresh: stage-2 собирает stage-3"
SALTIC_BOOTSTRAP_COMPILER="$work/stage-2/toolchain.elf" \
SALTIC_BUILD_DIR="$work/stage-3" \
SALTIC_HEAP_BYTES="$heap_bytes" \
bash os/bootstrap/build.sh \
    "$source_path" \
    "$work/stage-3/toolchain.elf" \
    "$work/stage-3/toolchain.s"

echo "bootstrap refresh: проверяю fixed point"
diff -u "$work/stage-2/toolchain.s" "$work/stage-3/toolchain.s"
cmp "$work/stage-2/toolchain.elf" "$work/stage-3/toolchain.elf"

cp "$work/stage-3/toolchain.elf" os/bootstrap/compiler.elf

echo "bootstrap refresh: compiler.elf обновлён"
sha256sum os/bootstrap/compiler.elf
