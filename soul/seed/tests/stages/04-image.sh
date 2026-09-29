#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"
seed_enter_dev_shell "$0" "$@"

seed_stage 4 "ELF-образ"

seed_pending "ELF-образ" \
    "production compiler ещё не передаёт machine.Program собственному ELF-builder" \
    "bootstrap build всё ещё создаёт промежуточный .s" \
    "host и qemu-virt production images всё ещё компонует внешний linker"
