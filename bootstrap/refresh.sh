#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

work="${SALTIC_BOOTSTRAP_REFRESH_DIR:-.cache/build/bootstrap-refresh}"
heap_bytes="${SALTIC_BOOTSTRAP_REFRESH_HEAP_BYTES:-536870912}"
source_path="${1:-s2/toolchain.saltic}"

mkdir -p "$work/stage-1" "$work/stage-2"

echo "bootstrap refresh: текущее поколение собирает stage-1"
SALTIC_BUILD_DIR="$work/stage-1" \
SALTIC_HEAP_BYTES="$heap_bytes" \
bash bootstrap/build.sh \
    "$source_path" \
    "$work/stage-1/toolchain.elf" \
    "$work/stage-1/toolchain.s"

echo "bootstrap refresh: stage-1 собирает stage-2"
SALTIC_BOOTSTRAP_COMPILER="$work/stage-1/toolchain.elf" \
SALTIC_BUILD_DIR="$work/stage-2" \
SALTIC_HEAP_BYTES="$heap_bytes" \
bash bootstrap/build.sh \
    "$source_path" \
    "$work/stage-2/toolchain.elf" \
    "$work/stage-2/toolchain.s"

echo "bootstrap refresh: проверяю fixed point"
diff -u "$work/stage-1/toolchain.s" "$work/stage-2/toolchain.s"
cmp "$work/stage-1/toolchain.elf" "$work/stage-2/toolchain.elf"

cp "$work/stage-2/toolchain.elf" bootstrap/compiler.elf

echo "bootstrap refresh: compiler.elf обновлён"
sha256sum bootstrap/compiler.elf
