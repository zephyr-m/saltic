#!/usr/bin/env bash
# Эталоны кодировщика x86-64: каждую команду из tests/x86-encoder.saltic
# (строка check(suite, "<команда>", …, "<байты>")) собирает настоящий GNU as,
# байты сверяются с эталоном в тесте. --print — только напечатать байты as
# («команда | байты»), чтобы вписать новый эталон. as/objcopy — из системы,
# иначе из nixpkgs#binutils. Промежуточные файлы — .cache/build/workbench/x86-encoder/.
source "$(dirname "$0")/../bootstrap/stamp.sh"
saltic_stamp_output "$0" "$@"
cd "$(dirname "$0")/.." || exit 1
W=.cache/build/workbench/x86-encoder
mkdir -p "$W"
mode="${1:-check}"

if ! command -v as > /dev/null || ! command -v objcopy > /dev/null; then
    echo "as/objcopy нет в системе — перезапускаюсь в nix shell nixpkgs#binutils"
    exec nix --extra-experimental-features "nix-command flakes" shell nixpkgs#binutils \
        --command bash "$0" "$@"
fi
echo "шаг 1: GNU as — $(as --version | head -n 1)"

# Байты одной команды (или нескольких через «;») текстом «48 89 e0».
assemble() {
    printf '.intel_syntax noprefix\n%s\n' "$1" > "$W/one.s"
    as --64 -o "$W/one.o" "$W/one.s" 2> "$W/one.err" || return 1
    objcopy -O binary -j .text "$W/one.o" "$W/one.bin" || return 1
    od -An -v -tx1 "$W/one.bin" | tr -s ' \n' ' ' | sed 's/^ //; s/ $//'
}

lines="$(grep -o 'check(suite, "[^"]*", .*"[^"]*")' tests/x86-encoder.saltic)"
total="$(printf '%s\n' "$lines" | grep -c .)"
echo "шаг 2: команд в тесте — $total, собираю по одной"
passed=0
failed=0
while IFS= read -r line; do
    command="$(sed -E 's/^check\(suite, "([^"]*)".*/\1/' <<< "$line")"
    expected="$(sed -E 's/.*"([^"]*)"\)$/\1/' <<< "$line")"
    if ! actual="$(assemble "$command")"; then
        echo "  as не понял «$command»: $(head -n 1 "$W/one.err")"
        failed=$((failed + 1))
        continue
    fi
    if [[ "$mode" == "--print" ]]; then
        echo "$command | $actual"
    elif [[ "$actual" == "$expected" ]]; then
        passed=$((passed + 1))
    else
        echo "  расходится «$command»: as даёт «$actual», в тесте «$expected»"
        failed=$((failed + 1))
    fi
done <<< "$lines"
if [[ "$mode" == "--print" ]]; then
    echo "шаг 3: байты напечатаны, ошибок as — $failed"
else
    echo "шаг 3: совпало $passed из $total, расходится $failed"
fi
(( failed == 0 ))
