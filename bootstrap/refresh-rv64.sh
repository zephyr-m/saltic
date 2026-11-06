#!/usr/bin/env bash
# Самосборка на RV64 — для релиза (just rv64), не для каждого global-check:
# под qemu-riscv64 она идёт минуты. Родной x86-64 компилятор с полки собирает
# компилятор под RV64 (stage-2), тот под qemu-riscv64 собирает себя (stage-3);
# stage-2 = stage-3 — на полку saltic-<версия>-compiler-rv64-linux с паспортом
# (вне git, выводится из загрузочного, как qemu-virt). Куча 1 ГБ: адреса
# программы на RV64 пока ниже 4 ГБ (раскладка на 32-битных word).
source "$(dirname "$0")/stamp.sh"
saltic_stamp_output "$0" "$@"
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
source bootstrap/names.sh

if ! command -v qemu-riscv64 >/dev/null 2>&1; then
    if [[ "${SALTIC_REFRESH_RV64_IN_DEV_SHELL:-}" == "1" ]]; then
        echo "bootstrap rv64: qemu-riscv64 отсутствует внутри проектного Nix shell" >&2
        exit 1
    fi
    echo "bootstrap rv64: вхожу в проектный Nix shell"
    exec nix --extra-experimental-features "nix-command flakes" develop "$root" --command \
        env SALTIC_REFRESH_RV64_IN_DEV_SHELL=1 bash "$root/bootstrap/refresh-rv64.sh" "$@"
fi

work=.cache/build/bootstrap-rv64
heap_bytes="${SALTIC_BOOTSTRAP_RV64_HEAP_BYTES:-1073741824}"
source_path="${1:-soul/seed/selfhost/toolchain.saltic}"
time_tool="$(type -P time || true)"
mkdir -p "$work"
rm -f "$work"/toolchain-rv64*

native="$(saltic_native_compiler)"
echo "bootstrap rv64: $(basename "$native") собирает компилятор под RV64"
"$native" "$source_path" "$work/toolchain-rv64-stage2" "$heap_bytes" rv64 > "$work/stage2.log" 2>&1 \
    || { tail -5 "$work/stage2.log" >&2; exit 1; }
chmod +x "$work/toolchain-rv64-stage2"

echo "bootstrap rv64: компилятор RV64 собирает себя под qemu-riscv64"
measured=()
[[ -n "$time_tool" ]] && measured=("$time_tool" -o "$work/stage3.time" -f "%M %U %S")
started=$EPOCHREALTIME
"${measured[@]}" qemu-riscv64 -B 0x100000000 "$work/toolchain-rv64-stage2" "$source_path" \
    "$work/toolchain-rv64-stage3" "$heap_bytes" rv64 > "$work/stage3.log" 2>&1 \
    || { tail -5 "$work/stage3.log" >&2; exit 1; }
seconds="$(saltic_seconds_since "$started")"

echo "bootstrap rv64: проверяю fixed point на RV64 (stage-2 = stage-3)"
cmp "$work/toolchain-rv64-stage2" "$work/toolchain-rv64-stage3"
echo "bootstrap rv64: самосборка под qemu-riscv64 за $seconds с"

path="$(saltic_compiler_path rv64 linux)"
for old in bootstrap/saltic-*-compiler-rv64-linux; do
    if [[ -f "$old" && "$old" != "$path" ]]; then rm -f "$old" "$old.txt"; fi
done
cp "$work/toolchain-rv64-stage3" "$path"
chmod +x "$path"
saltic_write_passport "$path" "rv64, linux (qemu-riscv64 -B 0x100000000)" "rv32i, rv64, x86_64" \
    "$native" "$heap_bytes" "сходится на RV64 (stage-2 = stage-3 под qemu-riscv64)" "$seconds" \
    самосборки "$work/stage3.time"
echo "bootstrap rv64: $(basename "$path") готов"
