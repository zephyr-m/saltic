#!/usr/bin/env bash
# Глобальная проверка любого изменения: самосборка с паспортами в bootstrap/,
# замер скорости против прежнего компилятора, быстрые тесты.
# Полный лог тестов сохраняется в .cache/build/workbench/global-check.log
cd "$(dirname "$0")/.." || exit 1
source bootstrap/names.sh
mkdir -p .cache/build/workbench
cp "$(saltic_bootstrap_compiler)" .cache/build/workbench/compiler-prev.elf
echo "== самосборка"
bash bootstrap/refresh.sh 2>&1 | grep "^bootstrap refresh: \(saltic\|прове\)\|^[0-9a-f]\{64\}"
compiler="$(saltic_bootstrap_compiler)"
for c in .cache/build/workbench/compiler-prev.elf "$compiler"; do
    echo "== время: $c"
    { time SALTIC_BOOTSTRAP_COMPILER=$c SALTIC_BUILD_DIR=.cache/build/bench/x \
        SALTIC_DIRECT_ONLY=1 bash bootstrap/build.sh soul/seed/toolchain.saltic \
        .cache/build/bench/x.elf >/dev/null 2>&1; } 2>&1 | grep real
done
ls -l .cache/build/workbench/compiler-prev.elf "$compiler" | awk '{print $5, $9}'
echo "== тесты (полный лог: .cache/build/workbench/global-check.log)"
pattern='итог|проверка:|error|подтвержд|ок$|ok$|пройдена'
nix --extra-experimental-features "nix-command flakes" develop \
    --command bash tests/run.sh fast > .cache/build/workbench/global-check.log 2>&1
grep -E "$pattern" .cache/build/workbench/global-check.log | grep -v '\[ok\]'
echo "== упавших проверок: $(grep -c 'FAIL\]' .cache/build/workbench/global-check.log)"
