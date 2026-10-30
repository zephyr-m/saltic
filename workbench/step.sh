#!/usr/bin/env bash
# Проверка шага оптимизации: самосборка, замер скорости, быстрые тесты.
# Полный лог тестов сохраняется в .cache/build/workbench/step.log
cd "$(dirname "$0")/.." || exit 1
mkdir -p .cache/build/workbench
cp os/bootstrap/compiler.elf .cache/build/workbench/compiler-prev.elf
echo "== самосборка"
bash os/bootstrap/refresh.sh 2>&1 | tail -3
for c in .cache/build/workbench/compiler-prev.elf os/bootstrap/compiler.elf; do
    echo "== время: $c"
    { time SALTIC_BOOTSTRAP_COMPILER=$c SALTIC_BUILD_DIR=.cache/build/bench/x \
        SALTIC_DIRECT_ONLY=1 bash os/bootstrap/build.sh soul/seed/toolchain.saltic \
        .cache/build/bench/x.elf >/dev/null 2>&1; } 2>&1 | grep real
done
ls -l .cache/build/workbench/compiler-prev.elf os/bootstrap/compiler.elf | awk '{print $5, $9}'
echo "== тесты (полный лог: .cache/build/workbench/step.log)"
pattern='итог|проверка:|error|подтвержд|ок$|ok$|пройдена'
nix --extra-experimental-features "nix-command flakes" develop \
    --command bash tests/run.sh fast > .cache/build/workbench/step.log 2>&1
grep -E "$pattern" .cache/build/workbench/step.log | grep -v '\[ok\]'
echo "== упавших проверок: $(grep -c 'FAIL\]' .cache/build/workbench/step.log)"
