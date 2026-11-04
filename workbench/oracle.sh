#!/usr/bin/env bash
# Оракул родного x86-64: каждая программа репозитория собирается компилятором
# из текущих исходников под x86_64-translation (перевод RV32I) и x86_64-native
# (родной код), запускается на обеих и сравниваются stdout и код выхода.
# Размеры образов печатаются. Программы с аргументами и вводом (канон)
# получают tests/fixtures/input.txt. Использование: workbench/oracle.sh [файлы…];
# без аргументов — канон, тесты из tests/ и soul/seed/tests с эталонами.
source "$(dirname "$0")/../bootstrap/stamp.sh"
saltic_stamp_output "$0" "$@"
cd "$(dirname "$0")/.." || exit 1
source bootstrap/names.sh
W=.cache/build/workbench/oracle
HEAP=67108864
mkdir -p "$W" .cache/build/tests
status=0
shelf="${SALTIC_BOOTSTRAP_COMPILER:-$(saltic_native_compiler)}" || exit 1

echo "== stage-1 из текущих исходников"
if ! "$shelf" soul/seed/selfhost/toolchain.saltic "$W/stage-1" 4026531840 x86_64 > "$W/stage.log" 2>&1; then
    grep -v "^warning" "$W/stage.log" | tail -5
    exit 1
fi
chmod +x "$W/stage-1"

if (( $# == 0 )); then
    set -- soul/canonical/main.saltic tests/edges.saltic tests/dict.saltic tests/bytes.saltic tests/groups.saltic \
        tests/platform.saltic tests/json-rpc.saltic tests/diagnostics.saltic soul/seed/tests/memory.saltic \
        soul/seed/tests/fixed.saltic tests/fixtures/big-numbers.saltic tests/fixtures/imports.saltic
fi

cp tests/fixtures/input.txt "$W/input.txt"
for source in "$@"; do
    name="$(basename "$source" .saltic)"
    args=()
    [[ "$source" == soul/canonical/main.saltic ]] && args=("$W/input.txt" "$W/output-$name.txt")
    for target in x86_64-translation x86_64-native; do
        if ! "$W/stage-1" "$source" "$W/$name-$target" $HEAP $target > "$W/$name-$target.log" 2>&1; then
            echo "НЕ СОБРАЛСЯ: $name ($target)"
            grep -v "^warning" "$W/$name-$target.log" | tail -3
            status=1
            continue 2
        fi
        chmod +x "$W/$name-$target"
        "$W/$name-$target" "${args[@]}" > "$W/$name-$target.out" 2>&1
        echo "$?" > "$W/$name-$target.code"
    done
    if cmp -s "$W/$name-x86_64-translation.out" "$W/$name-x86_64-native.out" \
        && cmp -s "$W/$name-x86_64-translation.code" "$W/$name-x86_64-native.code"; then
        echo "одинаково: $name (код $(<"$W/$name-x86_64-native.code"); перевод $(stat -c %s "$W/$name-x86_64-translation") байт, родной $(stat -c %s "$W/$name-x86_64-native") байт)"
    else
        echo "РАЗЛИЧАЕТСЯ: $name (коды $(<"$W/$name-x86_64-translation.code") и $(<"$W/$name-x86_64-native.code"))"
        diff "$W/$name-x86_64-translation.out" "$W/$name-x86_64-native.out" | head -5
        status=1
    fi
done
exit $status
