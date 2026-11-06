#!/usr/bin/env bash
source "$(dirname "$0")/stamp.sh"
saltic_stamp_output "$0" "$@"
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
# Компилятору под RV64 — 1 ГБ: адреса программы на RV64 пока ниже 4 ГБ
# (раскладка на 32-битных word), а 4 ГБ кучи туда не влезают.
rv64_heap_bytes="${SALTIC_BOOTSTRAP_RV64_HEAP_BYTES:-1073741824}"
source_path="${1:-soul/seed/selfhost/toolchain.saltic}"

mkdir -p "$work/stage-1" "$work/stage-2" "$work/stage-3"

bootstrap_compiler="$(saltic_bootstrap_compiler)"
mkdir -p "$work/previous"
rm -f "$work/previous/"* "$work"/stage-*/toolchain*
previous="$work/previous/$(basename "$bootstrap_compiler")"
cp "$bootstrap_compiler" "$previous"

# Самосборка идёт на x86-64. Компилятор, собравший исходники под x86_64, —
# это перевод той же RV-программы, которую он выдал бы под rv32i, поэтому
# x86-версия каждого поколения получается одной сборкой, без отдельного шага.
# Сравниваются по-прежнему rv32i-байты stage-2 и stage-3. Затем stage-2 собирает
# компилятор под RV64, тот под qemu-riscv64 собирает себя: stage-2 = stage-3 на
# RV64 — четвёртый компилятор полки (saltic-<версия>-compiler-rv64-linux).
stage_time="$(type -P time || true)"
# stage <компилятор> <цель> <результат> [куча] — компилятор RV64 идёт под qemu-riscv64
stage() {
    local compiler="$1" target="$2" output="$3" heap="${4:-$heap_bytes}"
    local measured=() runner=()
    [[ -n "$stage_time" ]] && measured=("$stage_time" -o "$output.time" -f "%M %U %S")
    [[ "$compiler" == *rv64* ]] && runner=(qemu-riscv64 -B 0x100000000)
    if ! "${measured[@]}" "${runner[@]}" "$compiler" "$source_path" "$output" "$heap" "$target" > "$output.log" 2>&1; then
        grep -v "^warning" "$output.log" | tail -5 >&2
        exit 1
    fi
    chmod +x "$output"
}

echo "bootstrap refresh: исходный compiler $bootstrap_compiler"
native="$(saltic_native_compiler)"

echo "bootstrap refresh: текущее поколение собирает stage-1 (x86-64)"
stage "$native" x86_64 "$work/stage-1/toolchain"

echo "bootstrap refresh: stage-1 собирает stage-2 (rv32i и x86-64)"
stage "$work/stage-1/toolchain" rv32i "$work/stage-2/toolchain.elf"
native_started=$EPOCHREALTIME
stage "$work/stage-1/toolchain" x86_64 "$work/stage-2/toolchain"
native_seconds="$(saltic_seconds_since "$native_started")"

echo "bootstrap refresh: stage-2 собирает stage-3 (rv32i)"
started=$EPOCHREALTIME
stage "$work/stage-2/toolchain" rv32i "$work/stage-3/toolchain.elf"
self_build_seconds="$(saltic_seconds_since "$started")"
echo "bootstrap refresh: новый компилятор собрал себя за $self_build_seconds с"
if [[ -f "$work/stage-3/toolchain.elf.time" ]]; then
    read -r self_kb self_user self_sys <"$work/stage-3/toolchain.elf.time"
    echo "bootstrap refresh: память самосборки $((self_kb / 1024)) МБ, процессор $(awk -v u="$self_user" -v s="$self_sys" 'BEGIN { printf "%.1f", u + s }') с"
fi

echo "bootstrap refresh: проверяю fixed point"
cmp "$work/stage-2/toolchain.elf" "$work/stage-3/toolchain.elf"

echo "bootstrap refresh: оракул — stage-1 собирает stage-2 переводом (x86_64-translation), тот собирает rv32i"
stage "$work/stage-1/toolchain" x86_64-translation "$work/stage-2/toolchain-translation"
stage "$work/stage-2/toolchain-translation" rv32i "$work/stage-3/toolchain-translation.elf"
cmp "$work/stage-3/toolchain.elf" "$work/stage-3/toolchain-translation.elf"
echo "bootstrap refresh: перевод даёт те же байты rv32i, что родной x86-64"

compiler="$(saltic_compiler_path rv32i linux .elf)"
if cmp -s "$work/stage-3/toolchain.elf" "$compiler" && [[ -f "${compiler%.elf}.txt" ]]; then
    echo "bootstrap refresh: $(basename "$compiler") не изменился"
    # Родная версия могла остаться переведённой (сбой прошлой самосборки):
    # тогда её место занимает stage-2 этой самосборки, байт в байт та же.
    native_path="$(saltic_compiler_path x86_64 linux)"
    if cmp -s "$work/stage-2/toolchain" "$native_path" \
        && ! grep -q "stage-2 самосборки" "$native_path.txt"; then
        saltic_write_passport "$native_path" "x86_64, linux" "rv32i, x86_64" \
            "$compiler" "$heap_bytes" "stage-2 самосборки на x86-64" "$native_seconds" сборки \
            "$work/stage-2/toolchain.time"
        echo "bootstrap refresh: паспорт $(basename "$native_path") обновлён"
    fi
else
    # Прежняя версия того же компилятора больше не нужна: новая заменяет её.
    for old in bootstrap/saltic-*-compiler-rv32i-linux.elf; do
        if [[ -f "$old" && "$old" != "$compiler" ]]; then rm -f "$old" "${old%.elf}.txt"; fi
    done
    cp "$work/stage-3/toolchain.elf" "$compiler"
    chmod +x "$compiler"
    saltic_write_passport "$compiler" "rv32i, linux (qemu-riscv32 -B 0x100000000)" "rv32i, x86_64" \
        "$previous" "$heap_bytes" "сходится на x86-64 (stage-2 = stage-3)" "$self_build_seconds" \
        самосборки "$work/stage-3/toolchain.elf.time"
    # stage-2 под x86_64 — перевод stage-2 rv32i, а он побайтово равен новому
    # компилятору: это и есть его родная версия.
    native_path="$(saltic_compiler_path x86_64 linux)"
    for old in bootstrap/saltic-*-compiler-x86_64-linux; do
        if [[ -f "$old" && "$old" != "$native_path" ]]; then rm -f "$old" "$old.txt"; fi
    done
    cp "$work/stage-2/toolchain" "$native_path"
    chmod +x "$native_path"
    saltic_write_passport "$native_path" "x86_64, linux" "rv32i, x86_64" \
        "$compiler" "$heap_bytes" "stage-2 самосборки на x86-64" "$native_seconds" сборки \
        "$work/stage-2/toolchain.time"
    echo "bootstrap refresh: $(basename "$compiler") обновлён"
fi
sha256sum "$compiler"

native="$(saltic_native_compiler)"
echo "bootstrap refresh: $(basename "$native") готов"

echo "bootstrap refresh: stage-2 (x86-64) собирает компилятор под RV64"
stage "$work/stage-2/toolchain" rv64 "$work/stage-2/toolchain-rv64" "$rv64_heap_bytes"
echo "bootstrap refresh: компилятор RV64 собирает себя под qemu-riscv64"
rv64_started=$EPOCHREALTIME
stage "$work/stage-2/toolchain-rv64" rv64 "$work/stage-3/toolchain-rv64" "$rv64_heap_bytes"
rv64_seconds="$(saltic_seconds_since "$rv64_started")"
echo "bootstrap refresh: проверяю fixed point на RV64 (stage-2 = stage-3)"
cmp "$work/stage-2/toolchain-rv64" "$work/stage-3/toolchain-rv64"
echo "bootstrap refresh: новый компилятор RV64: самосборка под qemu-riscv64 за $rv64_seconds с"
rv64_path="$(saltic_compiler_path rv64 linux)"
if cmp -s "$work/stage-3/toolchain-rv64" "$rv64_path" && [[ -f "$rv64_path.txt" ]]; then
    echo "bootstrap refresh: $(basename "$rv64_path") не изменился"
else
    for old in bootstrap/saltic-*-compiler-rv64-linux; do
        if [[ -f "$old" && "$old" != "$rv64_path" ]]; then rm -f "$old" "$old.txt"; fi
    done
    cp "$work/stage-3/toolchain-rv64" "$rv64_path"
    chmod +x "$rv64_path"
    saltic_write_passport "$rv64_path" "rv64, linux (qemu-riscv64 -B 0x100000000)" "rv32i, rv64, x86_64" \
        "$native" "$rv64_heap_bytes" "сходится на RV64 (stage-2 = stage-3 под qemu-riscv64)" "$rv64_seconds" \
        самосборки "$work/stage-3/toolchain-rv64.time"
    echo "bootstrap refresh: $(basename "$rv64_path") обновлён"
fi

qemu_virt="$(saltic_qemu_virt_compiler)"
echo "bootstrap refresh: $(basename "$qemu_virt") готов"
