#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
seed_enter_dev_shell "$0" "$@"

seed_stage 2 "ABI"
seed_run_current abi

seed_pending "ABI" \
    "compiler/abi.saltic ещё не реализует принятый call ABI" \
    "нет машинной проверки восьми аргументов и raw fixed через границу skill" \
    "нет наблюдаемой проверки a0=value, a1=raw error id и 16-байтовых object headers"
