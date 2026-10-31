#!/usr/bin/env bash
# Глобальная проверка любого изменения: самосборка с паспортами в bootstrap/,
# замер скорости против прежнего компилятора, быстрые тесты.
# Полный лог тестов сохраняется в .cache/build/workbench/global-check.log
source "$(dirname "$0")/../bootstrap/stamp.sh"
saltic_stamp_output "$0" "$@"
cd "$(dirname "$0")/.." || exit 1
source bootstrap/names.sh
mkdir -p .cache/build/workbench .cache/build/bench
prev=.cache/build/workbench/compiler-prev
cp "$(saltic_bootstrap_compiler)" "$prev.elf"
cp "$(saltic_native_compiler)" "$prev.native"
echo "== самосборка"
bash bootstrap/refresh.sh 2>&1 | grep "^bootstrap refresh: \(saltic\|прове\)\|^[0-9a-f]\{64\}"
compiler="$(saltic_bootstrap_compiler)"
for c in "$prev.native" "$(saltic_native_compiler)"; do
    echo "== время: $c"
    { time "$c" soul/seed/selfhost/toolchain.saltic .cache/build/bench/x.elf 4026531840 rv32i > /dev/null 2>&1; } 2>&1 | grep real
done
ls -l "$prev.elf" "$compiler" | awk '{print $5, $9}'
echo "== тесты (полный лог: .cache/build/workbench/global-check.log)"
pattern='итог|проверка:|error|подтвержд|ок$|ok$|пройдена|^x86-64:|^uefi: образ грузится'
nix --extra-experimental-features "nix-command flakes" develop \
    --command bash tests/run.sh fast 2>&1 | tee .cache/build/workbench/global-check.log \
    | grep --line-buffered -E "$pattern" | grep --line-buffered -v '\[ok\]'
tests_status=${PIPESTATUS[0]}
echo "== упавших проверок: $(grep -c 'FAIL\]' .cache/build/workbench/global-check.log)"
if [[ "$tests_status" != "0" ]]; then
    echo "== ПРОГОН ОБОРВАЛСЯ (код $tests_status), последние строки лога:"
    grep -v '\[ok\]' .cache/build/workbench/global-check.log | tail -12
    exit "$tests_status"
fi
