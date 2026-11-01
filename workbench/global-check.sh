#!/usr/bin/env bash
# Глобальная проверка любого изменения: самосборка с паспортами в bootstrap/,
# время самосборки против прошлого прогона, тесты на rv32i.
# Полный лог тестов сохраняется в .cache/build/workbench/global-check.log
source "$(dirname "$0")/../bootstrap/stamp.sh"
saltic_stamp_output "$0" "$@"
cd "$(dirname "$0")/.." || exit 1
source bootstrap/names.sh
mkdir -p .cache/build/workbench
prev=.cache/build/workbench/compiler-prev
cp "$(saltic_bootstrap_compiler)" "$prev.elf"
echo "== самосборка"
bash bootstrap/refresh.sh 2>&1 | tee .cache/build/workbench/refresh.log \
    | grep "^bootstrap refresh: \(saltic\|прове\|новый\)\|^[0-9a-f]\{64\}"
# Скорость: время самосборки против прошлого прогона.
seconds="$(grep -o 'собрал себя за [0-9.]*' .cache/build/workbench/refresh.log | grep -o '[0-9.]*$')"
last=.cache/build/workbench/self-build-seconds
[[ -f "$last" ]] && echo "== время самосборки: было $(<"$last") с, стало $seconds с"
echo "$seconds" > "$last"
compiler="$(saltic_bootstrap_compiler)"
echo "== размер: было $(stat -c %s "$prev.elf"), стало $(stat -c %s "$compiler") байт"
echo "== тесты (полный лог: .cache/build/workbench/global-check.log)"
pattern='итог|проверка:|error|подтвержд|ок$|ok$|пройдена|^x86-64:|^uefi: образ грузится'
nix --extra-experimental-features "nix-command flakes" develop \
    --command bash tests/run.sh 2>&1 | tee .cache/build/workbench/global-check.log \
    | grep --line-buffered -E "$pattern" | grep --line-buffered -v '\[ok\]'
tests_status=${PIPESTATUS[0]}
echo "== упавших проверок: $(grep -c 'FAIL\]' .cache/build/workbench/global-check.log)"
if [[ "$tests_status" != "0" ]]; then
    echo "== ПРОГОН ОБОРВАЛСЯ (код $tests_status), последние строки лога:"
    grep -v '\[ok\]' .cache/build/workbench/global-check.log | tail -12
    exit "$tests_status"
fi
