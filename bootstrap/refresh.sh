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
source_path="${1:-soul/seed/selfhost/toolchain.saltic}"

mkdir -p "$work/stage-1" "$work/stage-2" "$work/stage-3"

bootstrap_compiler="$(saltic_bootstrap_compiler)"
mkdir -p "$work/previous"
rm -f "$work/previous/"* "$work"/stage-*/toolchain*
previous="$work/previous/$(basename "$bootstrap_compiler")"
cp "$bootstrap_compiler" "$previous"

# Самосборка идёт на x86-64: каждое поколение собирается родным x86-64 и
# под rv64 и rv32i; fixed point — у всех трёх: байты stage-2 и stage-3 для
# rv64 (эталон в git), x86-64 (родной собирает сам себя) и rv32i (вторая
# сверка). Самосборка на самом RV64 (под qemu-riscv64, ~минута) — отдельно:
# bootstrap/refresh-rv64.sh, just rv64 — доказывает, что эталон собирает себя.
stage_time="$(type -P time || true)"
stage() {
    local compiler="$1" target="$2" output="$3"
    local measured=()
    [[ -n "$stage_time" ]] && measured=("$stage_time" -o "$output.time" -f "%M %U %S")
    if ! "${measured[@]}" "$compiler" "$source_path" "$output" "$heap_bytes" "$target" > "$output.log" 2>&1; then
        grep -v "^warning" "$output.log" | tail -5 >&2
        exit 1
    fi
    chmod +x "$output"
}

echo "bootstrap refresh: исходный compiler $bootstrap_compiler"
native="$(saltic_native_compiler)"
previous_native="$work/previous/$(basename "$native")"
cp "$native" "$previous_native"

echo "bootstrap refresh: текущее поколение собирает stage-1 (x86-64)"
stage "$native" x86_64 "$work/stage-1/toolchain"

echo "bootstrap refresh: stage-1 собирает stage-2 (rv64, x86-64 и rv32i)"
stage "$work/stage-1/toolchain" rv64 "$work/stage-2/toolchain-rv64"
stage "$work/stage-1/toolchain" x86_64 "$work/stage-2/toolchain"
stage "$work/stage-1/toolchain" rv32i "$work/stage-2/toolchain.elf"

echo "bootstrap refresh: stage-2 собирает stage-3 (rv64)"
started=$EPOCHREALTIME
stage "$work/stage-2/toolchain" rv64 "$work/stage-3/toolchain-rv64"
self_build_seconds="$(saltic_seconds_since "$started")"
echo "bootstrap refresh: новый компилятор собрал себя за $self_build_seconds с"
if [[ -f "$work/stage-3/toolchain-rv64.time" ]]; then
    read -r self_kb self_user self_sys <"$work/stage-3/toolchain-rv64.time"
    echo "bootstrap refresh: память самосборки $((self_kb / 1024)) МБ, процессор $(awk -v u="$self_user" -v s="$self_sys" 'BEGIN { printf "%.1f", u + s }') с"
fi

echo "bootstrap refresh: stage-2 собирает stage-3 (x86-64)"
native_started=$EPOCHREALTIME
stage "$work/stage-2/toolchain" x86_64 "$work/stage-3/toolchain"
native_seconds="$(saltic_seconds_since "$native_started")"
echo "bootstrap refresh: родной x86-64 собрал себя за $native_seconds с"

echo "bootstrap refresh: stage-2 собирает stage-3 (rv32i, вторая сверка)"
narrow_started=$EPOCHREALTIME
stage "$work/stage-2/toolchain" rv32i "$work/stage-3/toolchain.elf"
narrow_seconds="$(saltic_seconds_since "$narrow_started")"

echo "bootstrap refresh: проверяю fixed point (rv64, x86-64 и rv32i)"
cmp "$work/stage-2/toolchain-rv64" "$work/stage-3/toolchain-rv64"
cmp "$work/stage-2/toolchain" "$work/stage-3/toolchain"
cmp "$work/stage-2/toolchain.elf" "$work/stage-3/toolchain.elf"

targets="rv32i, rv64, x86_64"
compiler="$(saltic_compiler_path rv64 linux)"
native_path="$(saltic_compiler_path x86_64 linux)"
if cmp -s "$work/stage-3/toolchain-rv64" "$compiler" && [[ -f "$compiler.txt" ]]; then
    echo "bootstrap refresh: $(basename "$compiler") не изменился"
    # Паспорт родной версии мог остаться от другой сборки (сбой прошлой
    # самосборки): если она байт в байт stage-2 — паспорт переписывается.
    if cmp -s "$work/stage-2/toolchain" "$native_path" \
        && ! grep -q "время самосборки" "$native_path.txt"; then
        saltic_write_passport "$native_path" "x86_64, linux" "$targets" \
            "$previous_native" "$heap_bytes" "сходится на x86-64 (stage-2 = stage-3)" "$native_seconds" самосборки \
            "$work/stage-3/toolchain.time"
        echo "bootstrap refresh: паспорт $(basename "$native_path") обновлён"
    fi
else
    # Прежняя версия того же компилятора больше не нужна: новая заменяет её.
    for old in bootstrap/saltic-*-compiler-rv64-linux; do
        if [[ -f "$old" && "$old" != "$compiler" ]]; then rm -f "$old" "$old.txt"; fi
    done
    cp "$work/stage-3/toolchain-rv64" "$compiler"
    chmod +x "$compiler"
    saltic_write_passport "$compiler" "rv64, linux (qemu-riscv64 -B 0x100000000)" "$targets" \
        "$previous" "$heap_bytes" "сходится на x86-64 (stage-2 = stage-3); на RV64 — just rv64" "$self_build_seconds" \
        самосборки "$work/stage-3/toolchain-rv64.time"
    # stage-2 под x86_64 собран stage-1 (x86-64) и равен своему stage-3:
    # это родная версия нового компилятора.
    for old in bootstrap/saltic-*-compiler-x86_64-linux; do
        if [[ -f "$old" && "$old" != "$native_path" ]]; then rm -f "$old" "$old.txt"; fi
    done
    cp "$work/stage-2/toolchain" "$native_path"
    chmod +x "$native_path"
    saltic_write_passport "$native_path" "x86_64, linux" "$targets" \
        "$previous_native" "$heap_bytes" "сходится на x86-64 (stage-2 = stage-3)" "$native_seconds" самосборки \
        "$work/stage-3/toolchain.time"
    echo "bootstrap refresh: $(basename "$compiler") обновлён"
fi
sha256sum "$compiler"

# rv32i — вторая сверка: выводится из нового компилятора, в git не лежит.
narrow_path="$(saltic_compiler_path rv32i linux .elf)"
if cmp -s "$work/stage-3/toolchain.elf" "$narrow_path" && [[ -f "${narrow_path%.elf}.txt" ]]; then
    echo "bootstrap refresh: $(basename "$narrow_path") не изменился"
else
    for old in bootstrap/saltic-*-compiler-rv32i-linux.elf; do
        if [[ -f "$old" && "$old" != "$narrow_path" ]]; then rm -f "$old" "${old%.elf}.txt"; fi
    done
    cp "$work/stage-3/toolchain.elf" "$narrow_path"
    chmod +x "$narrow_path"
    saltic_write_passport "$narrow_path" "rv32i, linux (qemu-riscv32 -B 0x100000000)" "$targets" \
        "$native_path" "$heap_bytes" "вторая сверка: сходится на x86-64 (stage-2 = stage-3)" "$narrow_seconds" \
        сборки "$work/stage-3/toolchain.elf.time"
    echo "bootstrap refresh: $(basename "$narrow_path") обновлён (вторая сверка)"
fi

native="$(saltic_native_compiler)"
echo "bootstrap refresh: $(basename "$native") готов"

qemu_virt="$(saltic_qemu_virt_compiler)"
echo "bootstrap refresh: $(basename "$qemu_virt") готов"
