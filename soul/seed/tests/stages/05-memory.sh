#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
seed_enter_dev_shell "$0" "$@"

seed_stage 5 "память"

seed_pending "память" \
    "runtime ещё не записывает единые object headers" \
    "compiler ещё не публикует точные managed roots" \
    "нет неперемещающего mark-and-sweep и повторного использования блоков" \
    "нет длительного сценария на намеренно маленькой heap с циклами и живыми временными значениями"
