#!/usr/bin/env bash
# Остальные тесты после json-rpc. Полный лог: .cache/build/workbench/rest.log
cd "$(dirname "$0")/.." || exit 1
mkdir -p .cache/build/workbench
cases="${*:-tracer diagnostics minifier seed-contract machine abi memory jtml tasks qemu-virt}"
pattern='итог|проверка:|error|подтвержд|ок$|ok$'
for c in $cases; do
    echo "== $c"
    nix --extra-experimental-features "nix-command flakes" develop \
        --command bash tests/run.sh $c > .cache/build/workbench/rest-$c.log 2>&1
    grep -E "$pattern" .cache/build/workbench/rest-$c.log | grep -v '\[ok\]' | head -4
    echo "   упавших: $(grep -c 'FAIL\]' .cache/build/workbench/rest-$c.log)"
done
cat .cache/build/workbench/rest-*.log > .cache/build/workbench/rest.log
