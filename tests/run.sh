#!/usr/bin/env bash
source "$(dirname "$0")/../bootstrap/stamp.sh"
saltic_stamp_output "$0" "$@"
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

work_root="${SALTIC_TEST_DIR:-.cache/build/tests}"
mkdir -p "$work_root"
work="$(mktemp -d "$work_root/run.XXXXXX")"

cleanup() {
    local status=$?
    if (( status == 0 )); then
        rm -rf "$work"
    else
        echo "проверка: артефакты сохранены в $work" >&2
    fi
}

trap cleanup EXIT

# Хост, на котором исполняются тестовые программы: x86_64 — прямо на процессоре,
# rv32i — под qemu-riscv32. Код RISC-V как результат (гость VM, цель трассера,
# ELF машинного слоя) всегда исполняется в QEMU.
host="${SALTIC_TEST_HOST:-rv32i}"

run_built() {
    if [[ "$host" == "x86_64" ]]; then
        "$@"
    else
        qemu-riscv32 -B 0x100000000 "$@"
    fi
}

build() {
    local name="$1"
    local source="$2"
    local output="$3"
    local heap_bytes="${4:-536870912}"

    SALTIC_BUILD_DIR="$work/build/$name" \
    SALTIC_HEAP_BYTES="$heap_bytes" \
    SALTIC_TARGET="${SALTIC_TARGET:-$host}" \
    bash bootstrap/build.sh "$source" "$output"
}

checker_elf="$work/checker/checker.elf"

build_checker() {
    if [[ -f "$checker_elf" ]]; then
        return
    fi
    mkdir -p "$(dirname "$checker_elf")"
    build checker tests/checker.saltic "$checker_elf"
}

test_checker() {
    build_checker
    run_built "$checker_elf" \
        soul/canonical/main.saltic >"$work/checker/canonical.txt"
    run_built "$checker_elf" \
        soul/canonical/errors.saltic >"$work/checker/errors.txt"
    run_built "$checker_elf" \
        soul/canonical/support.saltic >>"$work/checker/errors.txt"

    test ! -s "$work/checker/canonical.txt"
    diff -u \
        soul/canonical/expected/errors.txt \
        "$work/checker/errors.txt"
    echo "чекер: нативная проверка пройдена"
}

test_fixed_types() {
    mkdir -p "$work/fixed-types"
    build_checker
    run_built "$checker_elf" \
        soul/seed/tests/fixed.saltic \
        >"$work/fixed-types/valid-diagnostics.txt"
    run_built "$checker_elf" \
        soul/seed/tests/fixed-errors.saltic \
        >"$work/fixed-types/errors.txt"

    test ! -s "$work/fixed-types/valid-diagnostics.txt"
    sed -E 's/^([^|]+)\|[0-9]+\|[0-9]+\|/\1|/' \
        "$work/fixed-types/errors.txt" \
        >"$work/fixed-types/errors-normalized.txt"
    diff -u \
        soul/seed/tests/expected/fixed-errors.txt \
        "$work/fixed-types/errors-normalized.txt"

    build fixed-types \
        soul/seed/tests/fixed.saltic \
        "$work/fixed-types/program.elf"
    run_built \
        "$work/fixed-types/program.elf" \
        >"$work/fixed-types/stdout.txt"
    diff -u \
        soul/seed/tests/expected/fixed.txt \
        "$work/fixed-types/stdout.txt"
    echo "фиксированные типы: нативная проверка пройдена"
}

test_modules() {
    mkdir -p "$work/modules"
    build_checker
    run_built "$checker_elf" \
        tests/fixtures/modules/main.saltic \
        >"$work/modules/main-diagnostics.txt"
    run_built "$checker_elf" \
        tests/fixtures/modules/errors.saltic \
        >"$work/modules/errors.txt"

    test ! -s "$work/modules/main-diagnostics.txt"
    diff -u \
        tests/expected/module-errors.txt \
        "$work/modules/errors.txt"

    build modules \
        tests/fixtures/modules/main.saltic \
        "$work/modules/program.elf"
    run_built \
        "$work/modules/program.elf" \
        >"$work/modules/stdout.txt"
    diff -u tests/expected/modules.txt "$work/modules/stdout.txt"
    echo "модули: нативная проверка пройдена"
}

test_json_rpc() {
    mkdir -p "$work/json-rpc"
    build json-rpc tests/json-rpc.saltic "$work/json-rpc/program.elf"
    run_built \
        "$work/json-rpc/program.elf" \
        >"$work/json-rpc/stdout.txt"
    diff -u tests/expected/json-rpc.txt "$work/json-rpc/stdout.txt"
    echo "json-rpc: ok"
}

test_diagnostics() {
    mkdir -p "$work/diagnostics"
    build diagnostics \
        tests/diagnostics.saltic \
        "$work/diagnostics/program.elf"
    run_built \
        "$work/diagnostics/program.elf" \
        >"$work/diagnostics/stdout.txt"
    diff -u \
        tests/expected/diagnostics.txt \
        "$work/diagnostics/stdout.txt"
    echo "диагностика: всё согласовано"
}

test_memory() {
    mkdir -p "$work/memory"
    build memory \
        soul/seed/tests/memory.saltic \
        "$work/memory/program.elf" \
        1048576
    run_built \
        "$work/memory/program.elf"
    echo "память: регионы освобождают мусор на куче 1 МБ"
}

test_native() {
    mkdir -p "$work/native"
    SALTIC_TARGET=x86_64 build native-canonical \
        soul/canonical/main.saltic \
        "$work/native/canonical" \
        67108864
    cp tests/fixtures/input.txt "$work/native/input.txt"
    "$work/native/canonical" \
        "$work/native/input.txt" \
        "$work/native/output.txt" \
        >"$work/native/stdout.txt"
    diff -u \
        soul/canonical/expected/output.txt \
        "$work/native/stdout.txt"
    test "$(<"$work/native/output.txt")" = "pip:0"
    SALTIC_TARGET=x86_64 build native-memory \
        soul/seed/tests/memory.saltic \
        "$work/native/memory" \
        1048576
    "$work/native/memory"
    SALTIC_TARGET=x86_64 build native-deep \
        tests/fixtures/deep-recursion.saltic \
        "$work/native/deep" \
        1048576
    if (ulimit -c 0; "$work/native/deep") >"$work/native/deep.txt" 2>&1; then
        echo "x86-64: переполнение стека прошло молча" >&2
        return 1
    fi
    if grep -q "вынырнул" "$work/native/deep.txt"; then
        echo "x86-64: переполненный стек вернулся из рекурсии" >&2
        return 1
    fi
    SALTIC_TARGET=x86_64 build native-keys \
        tests/fixtures/keys.saltic \
        "$work/native/keys" \
        1048576
    test "$(printf 'a\t\177 z\nq' | "$work/native/keys")" = "[a][tab][backspace][ ][z][enter]"
    SALTIC_TARGET=x86_64 build native-imports \
        tests/fixtures/imports.saltic \
        "$work/native/imports" \
        67108864
    test "$("$work/native/imports")" = "$(printf 'длина: 6\nпусто: yes\nстрок: 3\nфайл прочитан: yes')"
    SALTIC_TARGET=x86_64 build native-big-numbers \
        tests/fixtures/big-numbers.saltic \
        "$work/native/big-numbers" \
        1048576
    test "$("$work/native/big-numbers" | tr '\n' ' ')" = "-268435455 268435455 33554432 -33554433 100000000 33554431 -256 255 4096 -4097 200000001 268435455 "
    echo "x86-64: канон и память работают на родном процессоре, переполнение стека падает сразу, нажатия читаются, импорт работает, большие числа точны"
}

test_seed_contract() {
    mkdir -p "$work/seed-contract"
    build seed-contract \
        soul/seed/tests/contract.saltic \
        "$work/seed-contract/program.elf"
    run_built \
        "$work/seed-contract/program.elf"
    echo "seed: единый контракт подтверждён"
}

test_machine() {
    mkdir -p "$work/machine"
    build machine \
        soul/seed/tests/machine.saltic \
        "$work/machine/program.elf"
    run_built \
        "$work/machine/program.elf" \
        "$work/machine/ordinary.elf"
    test -s "$work/machine/ordinary.elf"
    chmod +x "$work/machine/ordinary.elf"
    qemu-riscv32 -B 0x100000000 "$work/machine/ordinary.elf"

    build testing-failure \
        tests/fixtures/testing-failure.saltic \
        "$work/machine/testing-failure.elf"
    if run_built \
        "$work/machine/testing-failure.elf" \
        >"$work/machine/testing-failure.txt"; then
        echo "проверка: намеренно проваленный тест завершился успешно" >&2
        return 1
    fi
    grep -Fq 'контроль провала -> 1  [FAIL]' "$work/machine/testing-failure.txt"
    grep -Fq 'итог: пройдено 0, провалено 1' "$work/machine/testing-failure.txt"
    grep -Fq 'проваленные проверки:' "$work/machine/testing-failure.txt"
    tail -n 1 "$work/machine/testing-failure.txt" \
        | grep -Fq -- '- контроль провала -> 1  [FAIL] (ожидалось 2)'
    echo "машина: кодирование и образ подтверждены"
}

test_abi() {
    mkdir -p "$work/abi"
    build abi \
        soul/seed/tests/abi.saltic \
        "$work/abi/program.elf"
    run_built \
        "$work/abi/program.elf"
    echo "ABI: единый контракт подтверждён"
}

test_qemu_virt() {
    SALTIC_QEMU_GRAPHICS_DIR="$work/qemu-virt" \
        bash os/target/qemu_virt/build-graphics.sh --check
}

test_uefi() {
    SALTIC_UEFI_DIR="$work/uefi" bash os/target/uefi_x86_64/build.sh
    SALTIC_UEFI_DIR="$work/uefi" bash os/target/uefi_x86_64/run.sh --check
}

test_jtml() {
    mkdir -p "$work/jtml"
    build jtml \
        tests/jtml.saltic \
        "$work/jtml/program.elf"
    run_built \
        "$work/jtml/program.elf"
    echo "JTML: дерево, раскладка и ввод подтверждены"
}

test_tasks() {
    mkdir -p "$work/tasks"
    build tasks \
        tests/tasks.saltic \
        "$work/tasks/program.elf"
    run_built \
        "$work/tasks/program.elf"
    echo "tasks: модель и интерфейс подтверждены"
}

test_closure() {
    local closure_work="$work/closure"
    mkdir -p "$closure_work"
    echo "closure: канон → ELF rv32i"
    SALTIC_BUILD_DIR="$closure_work/build" \
    SALTIC_HEAP_BYTES=67108864 \
    bash bootstrap/build.sh \
        soul/canonical/main.saltic \
        "$closure_work/canonical.elf"
    test -x "$closure_work/canonical.elf"
    local magic
    magic="$(od -An -t x1 -N 4 "$closure_work/canonical.elf" | tr -d ' \n')"
    test "$magic" = "7f454c46"
    cp tests/fixtures/input.txt "$closure_work/input.txt"
    echo "closure: ELF исполняется в QEMU"
    qemu-riscv32 -B 0x100000000 \
        "$closure_work/canonical.elf" \
        "$closure_work/input.txt" \
        "$closure_work/output.txt" \
        >"$closure_work/stdout.txt"
    diff -u \
        soul/canonical/expected/output.txt \
        "$closure_work/stdout.txt"
    test "$(<"$closure_work/output.txt")" = "pip:0"
    echo "closure: ok"
}

run_case() {
    case "$1" in
        checker) test_checker ;;
        fixed-types) test_fixed_types ;;
        modules) test_modules ;;
        json-rpc) test_json_rpc ;;
        diagnostics) test_diagnostics ;;
        seed-contract) test_seed_contract ;;
        machine) test_machine ;;
        abi) test_abi ;;
        memory) test_memory ;;
        native) test_native ;;
        qemu-virt) test_qemu_virt ;;
        uefi) test_uefi ;;
        jtml) test_jtml ;;
        tasks) test_tasks ;;
        closure) test_closure ;;
        *)
            echo "неизвестная проверка: $1" >&2
            exit 2
            ;;
    esac
}

if (( $# == 0 )); then
    set -- all
fi

if [[ "$1" == "platforms" ]]; then
    set -- qemu-virt uefi closure
elif [[ "$1" == "all" ]]; then
    set -- \
        checker \
        fixed-types \
        modules \
        json-rpc \
        diagnostics \
        seed-contract \
        machine \
        abi \
        memory \
        native \
        jtml \
        tasks
fi

for name in "$@"; do
    run_case "$name"
done
