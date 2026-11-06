#!/usr/bin/env bash
# Черновик релиза по Football Versioning (docs/process/FOOTBALL.md): читает коммиты с
# последнего тега v*, раскладывает их по префиксам и предлагает счёт и раздел
# CHANGELOG. feat: — фича (F), fix: — баг (B), refactor:/docs:/perf:/chore:/
# style:/test:/build:/ci: — уборка (C); release: пропускается; коммиты без
# префикса выводятся отдельно — их раскладывает автор.
# Скрипт только предлагает: одна строка CHANGELOG — одна единица счёта, а один
# коммит бывает и несколькими голами. Финальный счёт подтверждает автор.
# Запуск: just release-draft [база F:B:C] — по умолчанию база из VERSION.
# Черновик: .cache/build/release-draft.md
set -euo pipefail
cd "$(dirname "$0")/.."

base="${1:-$(tr -d '\r\n' < VERSION)}"
if [[ ! "$base" =~ ^([0-9]+):([0-9]+)(:([0-9]+))?$ ]]; then
    echo "релиз: база «$base» — не счёт F:B или F:B:C" >&2
    exit 1
fi
features="${BASH_REMATCH[1]}"
bugs="${BASH_REMATCH[2]}"
cleanup="${BASH_REMATCH[4]:-}"
if [[ -z "$cleanup" ]]; then
    echo "релиз: ⚠️ в базе $base нет уборки — считаю её с нуля; дай базу явно: just release-draft F:B:C"
    cleanup=0
fi

tag="$(git describe --tags --abbrev=0 --match 'v*')"
echo "релиз: база $base, последний тег $tag"

feat=()
fix=()
clean=()
loose=()
while IFS= read -r subject; do
    if [[ "$subject" =~ ^feat(\([^\)]*\))?!?:\ *(.*)$ ]]; then
        feat+=("${BASH_REMATCH[2]}")
    elif [[ "$subject" =~ ^fix(\([^\)]*\))?!?:\ *(.*)$ ]]; then
        fix+=("${BASH_REMATCH[2]}")
    elif [[ "$subject" =~ ^(refactor|docs|perf|chore|style|test|build|ci)(\([^\)]*\))?!?:\ *(.*)$ ]]; then
        clean+=("${BASH_REMATCH[3]}")
    elif [[ "$subject" =~ ^release: ]]; then
        continue
    else
        loose+=("$subject")
    fi
done < <(git log --no-merges --reverse --format='%s' "$tag..HEAD")

echo "релиз: ⚽ фичи ${#feat[@]}, 🐞 баги ${#fix[@]}, 🧹 уборка ${#clean[@]}, ❓ без префикса ${#loose[@]}"

score="$((features + ${#feat[@]})):$((bugs + ${#fix[@]})):$((cleanup + ${#clean[@]}))"
echo "релиз: предлагаю счёт $base → $score (без префикса не посчитаны)"

section() {
    local title="$1"
    shift
    [[ $# -eq 0 ]] && return
    printf '\n### %s\n\n' "$title"
    printf -- '- %s\n' "$@"
}

draft=.cache/build/release-draft.md
mkdir -p "$(dirname "$draft")"
{
    printf '## %s — %s\n' "$score" "$(date +%Y-%m-%d)"
    section "Фичи" "${feat[@]+"${feat[@]}"}"
    section "Баги" "${fix[@]+"${fix[@]}"}"
    section "Уборка" "${clean[@]+"${clean[@]}"}"
    section "Без префикса — разложить вручную" "${loose[@]+"${loose[@]}"}"
} > "$draft"

echo "релиз: черновик — $draft"
echo
cat "$draft"
