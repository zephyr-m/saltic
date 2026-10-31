#!/usr/bin/env bash
# Проверка рефакторинга без изменения смысла: текущие исходники собираются
# зафиксированным compiler.elf и компилятором из этих же исходников (stage-1).
# Результаты обязаны совпасть побайтово, а набор ошибок канона — с эталоном.
cd "$(dirname "$0")/.." || exit 1
W=.cache/build/workbench/same
mkdir -p "$W"
rm -f "$W"/*.elf
status=0

echo "== stage-1 из текущих исходников"
if ! SALTIC_BUILD_DIR="$W/stage" SALTIC_HEAP_BYTES=4026531840 SALTIC_DIRECT_ONLY=1 \
    bash bootstrap/build.sh soul/seed/toolchain.saltic "$W/stage-1.elf" > "$W/stage.log" 2>&1; then
    grep -v "^warning" "$W/stage.log" | tail -5
    exit 1
fi

for source in soul/seed/toolchain.saltic soul/seed/canonical/main.saltic soul/seed/tests/contract.saltic "$@"; do
    name="$(basename "$source" .saltic)"
    SALTIC_BUILD_DIR="$W/old-$name" SALTIC_DIRECT_ONLY=1 \
        bash bootstrap/build.sh "$source" "$W/old-$name.elf" > /dev/null 2>&1
    SALTIC_BOOTSTRAP_COMPILER="$W/stage-1.elf" SALTIC_BUILD_DIR="$W/new-$name" SALTIC_DIRECT_ONLY=1 \
        bash bootstrap/build.sh "$source" "$W/new-$name.elf" > "$W/new-$name.log" 2>&1
    if cmp -s "$W/old-$name.elf" "$W/new-$name.elf"; then
        echo "одинаково: $name"
    else
        echo "РАЗЛИЧАЕТСЯ: $name"
        grep -v "^warning" "$W/new-$name.log" | tail -3
        status=1
    fi
done

nix --extra-experimental-features "nix-command flakes" develop --command bash -c "
    SALTIC_BOOTSTRAP_COMPILER=$W/stage-1.elf SALTIC_BUILD_DIR=$W/checker \
        bash bootstrap/build.sh tests/checker.saltic $W/checker.elf > /dev/null 2>&1
    qemu-riscv32 -B 0x100000000 $W/checker.elf soul/seed/canonical/errors.saltic > $W/errors.txt
    qemu-riscv32 -B 0x100000000 $W/checker.elf soul/seed/canonical/support.saltic >> $W/errors.txt
    qemu-riscv32 -B 0x100000000 $W/checker.elf soul/seed/canonical/main.saltic > $W/canonical.txt
" 2>/dev/null
if diff -q soul/seed/canonical/expected/errors.txt "$W/errors.txt" > /dev/null && test ! -s "$W/canonical.txt"; then
    echo "ошибки канона: совпадают"
else
    echo "ошибки канона: РАЗЛИЧАЮТСЯ"
    status=1
fi
exit $status
