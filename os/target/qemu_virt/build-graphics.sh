#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root"

work="${SALTIC_QEMU_GRAPHICS_DIR:-.cache/build/qemu-graphics}"
mkdir -p "$work"

echo "графика: прямой ELF $work/program.elf"
SALTIC_BUILD_DIR="$work/build" \
    bash os/bootstrap/build.sh \
    os/main.saltic \
    "$work/program.elf"

echo "графика: сборка готова"

if [[ "${1:-}" == "--check" ]]; then
    magic="$(od -An -tx1 -N4 "$work/program.elf" | tr -d '[:space:]')"
    if [[ "$magic" != "7f454c46" ]]; then
        echo "графика: компилятор не создал ELF" >&2
        exit 1
    fi
    test -x "$work/program.elf"
    echo "графика: прямой ELF подтверждён"
fi
