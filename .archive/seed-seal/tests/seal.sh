#!/usr/bin/env bash
set -euo pipefail

tests_dir="$(cd "$(dirname "$0")" && pwd)"
source "$tests_dir/lib.sh"
seed_enter_dev_shell "$0" "$@"

for stage in \
    01-language.sh \
    02-abi.sh \
    03-machine.sh \
    04-image.sh \
    05-memory.sh \
    06-host.sh \
    07-virt.sh \
    08-closure.sh
do
    bash "$tests_dir/stages/$stage"
done

printf 'seed: все восемь этапов закрыты\n'
