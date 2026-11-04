#!/usr/bin/env bash
# Проверка всех поддерживаемых хостов перед релизом: тесты на x86-64 Linux
# прямо на процессоре, затем qemu-virt (графика), x86-64 UEFI и rv32i Linux
# (closure: канон собирается и исполняется в QEMU). rv32i Linux целиком проверяет
# global-check.sh. Полный лог: .cache/build/workbench/hosts.log
source "$(dirname "$0")/../bootstrap/stamp.sh"
saltic_stamp_output "$0" "$@"
cd "$(dirname "$0")/.." || exit 1
mkdir -p .cache/build/workbench
log=.cache/build/workbench/hosts.log
pattern='итог|проверка:|error|подтвержд|ок$|ok$|пройдена|^x86-64:|^uefi: образ грузится'
: > "$log"
status=0
aborted=0
for step in "x86_64 all" "x86_64-translation all" "rv32i platforms"; do
    read -r host group <<< "$step"
    echo "== $host: $group"
    SALTIC_TEST_HOST="$host" nix --extra-experimental-features "nix-command flakes" develop \
        --command bash tests/run.sh "$group" 2>&1 | tee -a "$log" \
        | grep --line-buffered -E "$pattern" | grep --line-buffered -v '\[ok\]'
    step_status=${PIPESTATUS[0]}
    if [[ "$step_status" != "0" ]]; then
        echo "== $host: $group ОБОРВАЛСЯ (код $step_status), последние строки лога:"
        grep -v '\[ok\]' "$log" | tail -12
        status=$step_status
        aborted=$((aborted + 1))
    fi
done
echo "== упавших проверок: $(grep -c 'FAIL\]' "$log"), оборвавшихся прогонов: $aborted"
exit "$status"
