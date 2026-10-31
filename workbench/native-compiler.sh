#!/usr/bin/env bash
# Веха 3: компилятор Saltic, переведённый на x86-64, против компилятора под QEMU.
cd "$(dirname "$0")/.." || exit 1
mkdir -p .cache/build/workbench
R=.cache/build/workbench/x86
H=4026531840
echo "== 1. перевожу компилятор в x86-64 (stage-1 под QEMU)"
time SALTIC_BOOTSTRAP_COMPILER=$R/stage-1.elf SALTIC_TARGET=x86_64 SALTIC_BUILD_DIR=$R/native-build \
    SALTIC_HEAP_BYTES=$H bash bootstrap/build.sh soul/seed/toolchain.saltic $R/compiler.native 2>&1 \
    | grep -v "^warning\|Nix shell"
ls -l $R/compiler.native | awk '{print "размер:", $5}'
echo "== 2. родной компилятор собирает toolchain под RISC-V"
time $R/compiler.native soul/seed/toolchain.saltic $R/from-native.elf $H rv32i | tail -1
echo "== 3. тот же компилятор под QEMU собирает то же самое"
time SALTIC_BOOTSTRAP_COMPILER=$R/stage-1.elf SALTIC_BUILD_DIR=$R/rv-build SALTIC_HEAP_BYTES=$H \
    SALTIC_DIRECT_ONLY=1 bash bootstrap/build.sh soul/seed/toolchain.saltic $R/from-rv.elf 2>&1 | tail -1
echo "== 4. сравнение"
cmp $R/from-native.elf $R/from-rv.elf && echo "ПОБАЙТОВО ОДИНАКОВО"
