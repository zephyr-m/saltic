#!/usr/bin/env bash
# Лимиты канона архитектуры (docs/process/Code_Architecture_канон_для_агентов.md):
# не больше LIMIT_CODE строк кода в рукописном .saltic (пустые и `--` не в счёт)
# и не больше LIMIT_HEADER строк шапки (всё до первой строки кода). Смотрит
# файлы из git, кроме .archive/ и папок generated/.
# Уже известные нарушения — в workbench/limits-known.txt («путь строк_кода
# строк_шапки», правит автор): им можно не расти, но не ухудшаться. Падает,
# если нарушение новое или известное выросло. Вызывается `just limits` и
# global-check.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

LIMIT_CODE=500
LIMIT_HEADER=16
known=workbench/limits-known.txt

measure() {
    awk 'BEGIN { header = 0; code = 0; top = 1 }
    {
        line = $0
        sub(/^[ \t]+/, "", line)
        if (top) {
            if (line ~ /^--/ || line == "") { header++; next }
            top = 0
        }
        if (line != "" && line !~ /^--/) code++
    }
    END { printf "%d %d\n", code, header }' "$1"
}

echo "лимиты канона: код до $LIMIT_CODE строк, шапка до $LIMIT_HEADER строк"
checked=0
old=0
new=0
grown=0
while read -r file; do
    checked=$((checked + 1))
    read -r code header < <(measure "$file")
    (( code > LIMIT_CODE || header > LIMIT_HEADER )) || continue
    record="$(grep -F -- "$file " "$known" 2>/dev/null | head -1)"
    if [[ -z "$record" ]]; then
        echo "лимиты канона: новое нарушение $file — кода $code, шапка $header"
        new=$((new + 1))
        continue
    fi
    read -r _ known_code known_header <<<"$record"
    if (( code > LIMIT_CODE && code > known_code )) || (( header > LIMIT_HEADER && header > known_header )); then
        echo "лимиты канона: выросло $file — кода $known_code → $code, шапка $known_header → $header"
        grown=$((grown + 1))
        continue
    fi
    old=$((old + 1))
done < <(git ls-files '*.saltic' | grep -v -e '^\.archive/' -e '/generated/')
echo "лимиты канона: файлов $checked, известных нарушений $old, новых $new, выросших $grown"
(( new == 0 && grown == 0 ))
