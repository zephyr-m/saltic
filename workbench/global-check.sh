#!/usr/bin/env bash
# Глобальная проверка любого изменения: лимиты канона (workbench/limits.saltic),
# самосборка с паспортами в bootstrap/, время самосборки против прошлого
# прогона, тесты на rv32i; в самом конце — сколько заняла вся проверка.
# Полный лог тестов сохраняется в .cache/build/workbench/global-check.log
source "$(dirname "$0")/../bootstrap/stamp.sh"
saltic_stamp_output "$0" "$@"
cd "$(dirname "$0")/.." || exit 1
source bootstrap/names.sh
started="$EPOCHREALTIME"
report_duration() {
    local seconds
    seconds="$(saltic_seconds_since "$started")"
    echo "== ⏱️ глобальная проверка заняла $((${seconds%.*} / 60)) мин $((${seconds%.*} % 60)) с"
}
trap report_duration EXIT
mkdir -p .cache/build/workbench
prev=.cache/build/workbench/compiler-prev
cp "$(saltic_bootstrap_compiler)" "$prev.elf"
# Смайлики к строкам вывода: ✅ прошло, ❌ упало, 🏁 итог, 🔑 отпечаток.
decorate() {
    sed -u -E \
        -e '/метрики:/b' \
        -e '/подтвержд|пройдена$/{s/^(\[[0-9:]+\] )?/\1✅ /;b}' \
        -e '/провалено [1-9]|error|FAIL|упал|ошибк|сохранены в|молча|вернулся из|намеренно|неизвестная|новое нарушение|выросло /{s/^(\[[0-9:]+\] )?/\1❌ /;b}' \
        -e '/итог:/{s/^(\[[0-9:]+\] )?/\1🏁 /;b}' \
        -e '/^[0-9a-f]{64}/{s/^/🔑 /;b}' \
        -e 's/^(\[[0-9:]+\] )?/\1✅ /'
}
echo "== 📏 лимиты канона"
run_limits() {
    SALTIC_TARGET=x86_64 bash bootstrap/build.sh workbench/limits.saltic .cache/build/workbench/limits >/dev/null || return 1
    .cache/build/workbench/limits
}
run_limits 2>&1 | decorate
limits_status=${PIPESTATUS[0]}
if [[ "$limits_status" != "0" ]]; then
    echo "== 🚨 ЛИМИТЫ КАНОНА НАРУШЕНЫ: новый или выросший файл выше; самосборку не начинаю"
    exit "$limits_status"
fi
echo "== 🔨 самосборка"
run_refresh() {
    SALTIC_TARGET=x86_64 bash bootstrap/build.sh bootstrap/refresh.saltic .cache/build/workbench/refresh >/dev/null || return 1
    .cache/build/workbench/refresh ""
}
run_refresh 2>&1 | tee .cache/build/workbench/refresh.log \
    | grep "^bootstrap refresh: \(saltic\|прове\|новый\|родной\|памят\)\|^[0-9a-f]\{64\}" | decorate
refresh_status=${PIPESTATUS[0]}
if [[ "$refresh_status" != "0" ]]; then
    echo "== 🚨 САМОСБОРКА УПАЛА (код $refresh_status), последние строки лога:"
    tail -5 .cache/build/workbench/refresh.log
    exit "$refresh_status"
fi
# Скорость: время самосборки против прошлого прогона.
seconds="$(grep -o 'новый компилятор собрал себя за [0-9.]*' .cache/build/workbench/refresh.log | grep -o '[0-9.]*$')"
last=.cache/build/workbench/self-build-seconds
[[ -f "$last" ]] && echo "== ⏱️ время самосборки: было $(<"$last") с, стало $seconds с"
echo "$seconds" > "$last"
memory="$(grep -o 'память самосборки [0-9]*' .cache/build/workbench/refresh.log | grep -o '[0-9]*$')"
last_memory=.cache/build/workbench/self-build-memory
if [[ -n "$memory" ]]; then
    [[ -f "$last_memory" ]] && echo "== 🧠 память самосборки: было $(<"$last_memory") МБ, стало $memory МБ"
    echo "$memory" > "$last_memory"
fi
compiler="$(saltic_bootstrap_compiler)"
echo "== 📦 размер: было $(stat -c %s "$prev.elf"), стало $(stat -c %s "$compiler") байт"
echo "== 🧪 тесты (полный лог: .cache/build/workbench/global-check.log)"
pattern='итог|проверка:|метрики:|error|подтвержд|ок$|ok$|пройдена|^x86-64:|^uefi: образ грузится'
nix --extra-experimental-features "nix-command flakes" develop \
    --command bash tests/run.sh 2>&1 | tee .cache/build/workbench/global-check.log \
    | grep --line-buffered -E "$pattern" | grep --line-buffered -v '\[ok\]' | decorate
tests_status=${PIPESTATUS[0]}
failed="$(grep -c 'FAIL\]' .cache/build/workbench/global-check.log)"
if [[ "$failed" == "0" ]]; then
    echo "== 🎉 упавших проверок: 0"
else
    echo "== 💥 упавших проверок: $failed"
fi
if [[ "$tests_status" != "0" ]]; then
    echo "== 🚨 ПРОГОН ОБОРВАЛСЯ (код $tests_status), последние строки лога:"
    grep -v '\[ok\]' .cache/build/workbench/global-check.log | tail -12
    exit "$tests_status"
fi
