#!/usr/bin/env bash
set -euo pipefail

seed_tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
seed_dir="$(cd "$seed_tests_dir/.." && pwd)"
repo_root="$(cd "$seed_dir/../.." && pwd)"
seed_work_root="${SALTIC_SEED_TEST_DIR:-$repo_root/.cache/build/seed-tests}"

mkdir -p "$seed_work_root"

seed_enter_dev_shell() {
    local script="$1"
    shift

    if command -v qemu-riscv32 >/dev/null 2>&1; then
        return
    fi
    if [[ "${SALTIC_SEED_IN_DEV_SHELL:-}" == "1" ]]; then
        printf 'seed: qemu-riscv32 отсутствует внутри проектного Nix shell\n' >&2
        return 1
    fi
    if ! command -v nix >/dev/null 2>&1; then
        printf 'seed: не найдены ни qemu-riscv32, ни nix\n' >&2
        return 1
    fi

    local script_dir
    local script_path
    script_dir="$(cd "$(dirname "$script")" && pwd)"
    script_path="$script_dir/$(basename "$script")"

    printf 'seed: вхожу в проектный Nix shell\n'
    exec nix \
        --extra-experimental-features "nix-command flakes" \
        develop "$repo_root" --command \
        env \
        SALTIC_SEED_IN_DEV_SHELL=1 \
        SALTIC_SEED_TEST_DIR="$seed_work_root" \
        bash "$script_path" "$@"
}

seed_stage() {
    local number="$1"
    local name="$2"
    printf 'seed %s/8: %s\n' "$number" "$name"
}

seed_run_current() {
    (
        cd "$repo_root"
        SALTIC_TEST_DIR="$seed_work_root/current" \
            bash tests/run.sh "$@"
    )
}

seed_require_file() {
    local relative="$1"
    if [[ ! -f "$repo_root/$relative" ]]; then
        printf 'seed: обязательный файл отсутствует: %s\n' "$relative" >&2
        return 1
    fi
}

seed_require_absent_file() {
    local relative="$1"
    if [[ -e "$repo_root/$relative" ]]; then
        printf 'seed: запрещённый остаток существует: %s\n' "$relative" >&2
        return 1
    fi
}

seed_forbid_pattern() {
    local pattern="$1"
    shift
    if rg -n -- "$pattern" "$@"; then
        printf 'seed: найден запрещённый внешний build-path: %s\n' "$pattern" >&2
        return 1
    fi
}

seed_pending() {
    local title="$1"
    shift
    printf 'seed: этап «%s» ещё не доказан:\n' "$title" >&2
    local item
    for item in "$@"; do
        printf '  - %s\n' "$item" >&2
    done
    return 1
}
