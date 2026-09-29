#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
seed_enter_dev_shell "$0" "$@"

seed_stage 1 "язык"
seed_run_current checker fixed-types modules diagnostics

seed_pending "язык" \
    "checker ещё не возвращает единое типизированное представление программы" \
    "compiler ещё не потребляет результат checker" \
    "нет отрицательных проверок мономорфной неоднозначности и смешанных типов одного skill"
