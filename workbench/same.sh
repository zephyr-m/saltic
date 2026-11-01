#!/usr/bin/env bash
# Проверка рефакторинга без изменения смысла: текущие исходники собираются
# компилятором с полки bootstrap/ и компилятором из этих же исходников (stage-1)
# под обе цели, rv32i и x86_64. Результаты обязаны совпасть побайтово, а набор
# ошибок канона — с эталоном. Оба компилятора работают родными x86-версиями.
source "$(dirname "$0")/../bootstrap/stamp.sh"
saltic_stamp_output "$0" "$@"
cd "$(dirname "$0")/.." || exit 1
source bootstrap/names.sh
W=.cache/build/workbench/same
HEAP=4026531840
mkdir -p "$W"
rm -f "$W"/*.out "$W"/stage-1
status=0
shelf="$(saltic_native_compiler)" || exit 1

echo "== stage-1 из текущих исходников"
if ! "$shelf" soul/seed/selfhost/toolchain.saltic "$W/stage-1" $HEAP x86_64 > "$W/stage.log" 2>&1; then
    grep -v "^warning" "$W/stage.log" | tail -5
    exit 1
fi
chmod +x "$W/stage-1"

for source in soul/seed/selfhost/toolchain.saltic soul/canonical/main.saltic soul/seed/tests/contract.saltic "$@"; do
    name="$(basename "$source" .saltic)"
    for target in rv32i x86_64; do
        "$shelf" "$source" "$W/old-$name-$target.out" $HEAP $target > /dev/null 2>&1
        "$W/stage-1" "$source" "$W/new-$name-$target.out" $HEAP $target > "$W/new-$name-$target.log" 2>&1
        if cmp -s "$W/old-$name-$target.out" "$W/new-$name-$target.out"; then
            echo "одинаково: $name ($target)"
        else
            echo "РАЗЛИЧАЕТСЯ: $name ($target)"
            echo "    размер: было $(stat -c %s "$W/old-$name-$target.out" 2>/dev/null), стало $(stat -c %s "$W/new-$name-$target.out" 2>/dev/null) байт"
            grep -v "^warning" "$W/new-$name-$target.log" | tail -3
            status=1
        fi
    done
done

"$W/stage-1" tests/checker.saltic "$W/checker.bin" $HEAP x86_64 > /dev/null 2>&1
chmod +x "$W/checker.bin"
{ "$W/checker.bin" soul/canonical/errors.saltic; "$W/checker.bin" soul/canonical/support.saltic; } > "$W/errors.txt"
"$W/checker.bin" soul/canonical/main.saltic > "$W/canonical.txt"
if diff -q soul/canonical/expected/errors.txt "$W/errors.txt" > /dev/null && test ! -s "$W/canonical.txt"; then
    echo "ошибки канона: совпадают"
else
    echo "ошибки канона: РАЗЛИЧАЮТСЯ"
    status=1
fi
exit $status
