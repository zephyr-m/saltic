#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

source_path="${1:-soul/seed/toolchain.saltic}"
compiler="${SALTIC_HEAP_AUDIT_COMPILER:-os/bootstrap/compiler.elf}"
work="${SALTIC_HEAP_AUDIT_DIR:-.cache/build/heap-audit}"
port="${SALTIC_HEAP_AUDIT_PORT:-12345}"
assembly="$work/toolchain.s"
source_map="$work/source-map.txt"

if [[ ! -f "$compiler" ]]; then
    echo "heap audit: компилятор не найден: $compiler" >&2
    exit 1
fi
if [[ ! -f "$source_path" ]]; then
    echo "heap audit: исходник не найден: $source_path" >&2
    exit 1
fi
if [[ ! "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
    echo "heap audit: неверный порт: $port" >&2
    exit 2
fi

debugger=""
if command -v riscv32-none-elf-gdb >/dev/null 2>&1; then
    debugger="riscv32-none-elf-gdb"
elif command -v gdb >/dev/null 2>&1; then
    debugger="gdb"
else
    echo "heap audit: GDB не найден" >&2
    exit 1
fi

mkdir -p "$work"

rg -n --no-heading --with-filename '^[[:space:]]*skill[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' soul --glob '*.saltic' \
    | awk -F: '
        {
            file = $1
            line = $2
            text = substr($0, length(file) + length(line) + 3)
            if (match(text, /skill[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)/, found)) {
                module = file
                sub(/^soul\//, "", module)
                sub(/\.saltic$/, "", module)
                gsub(/\//, "_", module)
                print "saltic_" module "_" found[1] "|" file ":" line
            }
        }
    ' >"$source_map"

rg -n --no-heading --with-filename '^rt_[A-Za-z_][A-Za-z0-9_]*:' soul/seed/runtime/runtime.saltic \
    | awk -F: '{ name = $3; sub(/:.*/, "", name); print name "|" $1 ":" $2 }' \
    >>"$source_map"

awk '
    /^[[:space:]]*skill[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/ {
        name = $2
        sub(/\(.*/, "", name)
        print "saltic_" name "|" FILENAME ":" FNR
    }
    /^[[:space:]]*program[[:space:]]*\(/ {
        print "saltic_program|" FILENAME ":" FNR
    }
' "$source_path" >>"$source_map"

sort -u -o "$source_map" "$source_map"

echo "heap audit: компилятор: $compiler"
echo "heap audit: исходник: $source_path"
echo "heap audit: строки показывают объявления навыков"
echo

qemu-riscv32 -g "$port" -B 0x100000000 \
    "$compiler" "$source_path" "$assembly" &
qemu_pid=$!

cleanup() {
    if kill -0 "$qemu_pid" 2>/dev/null; then
        kill "$qemu_pid" 2>/dev/null || true
    fi
    wait "$qemu_pid" 2>/dev/null || true
}
trap cleanup EXIT

sleep 0.2

SALTIC_HEAP_SOURCE_MAP="$source_map" \
    "$debugger" -q -nx "$compiler" \
    -ex "target remote :$port" \
    -x os/bootstrap/heap-audit.gdb
