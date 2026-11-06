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
# rv32i — под qemu-riscv32, rv64 — под qemu-riscv64. Код RISC-V как результат (гость VM, цель трассера,
# ELF машинного слоя) всегда исполняется в QEMU.
host="${SALTIC_TEST_HOST:-rv32i}"

source tests/metrics.sh

run_built() {
    if [[ "$host" == x86_64* ]]; then
        measure run "$@"
    elif [[ "$host" == rv64 ]]; then
        measure run qemu-riscv64 -B 0x100000000 "$@"
    else
        measure run qemu-riscv32 -B 0x100000000 "$@"
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
    measure build bash bootstrap/build.sh "$source" "$output"
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
    test ! -s "$work/checker/canonical.txt"

    local case name
    for case in soul/canonical/errors/*.saltic; do
        name="$(basename "$case" .saltic)"
        run_built "$checker_elf" "$case" >"$work/checker/errors-$name.txt"
        diff -u \
            "soul/canonical/expected/errors/$name.txt" \
            "$work/checker/errors-$name.txt"
    done
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

test_groups() {
    mkdir -p "$work/groups"
    build groups \
        tests/groups.saltic \
        "$work/groups/program.elf"
    run_built \
        "$work/groups/program.elf" \
        >"$work/groups/stdout.txt"
    diff -u \
        tests/expected/groups.txt \
        "$work/groups/stdout.txt"
    echo "группы: деревья от 33 элементов подтверждены"
}

test_bytes() {
    mkdir -p "$work/bytes"
    build bytes \
        tests/bytes.saltic \
        "$work/bytes/program.elf"
    run_built \
        "$work/bytes/program.elf" \
        >"$work/bytes/stdout.txt"
    diff -u \
        tests/expected/bytes.txt \
        "$work/bytes/stdout.txt"
    echo "буфер байтов: нули, запись на месте, ошибки по имени подтверждены"
}

test_edges() {
    mkdir -p "$work/edges"
    SALTIC_TARGET=rv32i build edges-rv32i \
        tests/edges.saltic \
        "$work/edges/rv32i.elf"
    SALTIC_TARGET=x86_64 build edges-x86_64 \
        tests/edges.saltic \
        "$work/edges/x86_64"
    SALTIC_TARGET=x86_64-translation build edges-x86_64-translation \
        tests/edges.saltic \
        "$work/edges/x86_64-translation"
    measure run qemu-riscv32 -B 0x100000000 "$work/edges/rv32i.elf" \
        >"$work/edges/rv32i.txt"
    measure run "$work/edges/x86_64" \
        >"$work/edges/x86_64.txt"
    measure run "$work/edges/x86_64-translation" \
        >"$work/edges/x86_64-translation.txt"
    diff -u tests/expected/edges.txt "$work/edges/rv32i.txt"
    diff -u tests/expected/edges.txt "$work/edges/x86_64.txt"
    diff -u tests/expected/edges.txt "$work/edges/x86_64-translation.txt"
    echo "граничные случаи: ошибки по имени, дерево Box, строки — одинаково под rv32i, x86_64 и x86_64-translation"
}

test_always() {
    mkdir -p "$work/always"
    SALTIC_TARGET=rv32i build always-rv32i \
        tests/always.saltic \
        "$work/always/rv32i.elf" \
        1048576
    SALTIC_TARGET=x86_64 build always-x86_64 \
        tests/always.saltic \
        "$work/always/x86_64" \
        1048576
    measure run qemu-riscv32 -B 0x100000000 "$work/always/rv32i.elf" \
        >"$work/always/rv32i.txt"
    measure run "$work/always/x86_64" \
        >"$work/always/x86_64.txt"
    diff -u tests/expected/always.txt "$work/always/rv32i.txt"
    diff -u tests/expected/always.txt "$work/always/x86_64.txt"
    echo "always: регион на оборот — 200 000 оборотов в 1 МБ, внешнее переживает уборку, под rv32i и x86_64"
}

test_rv64() {
    mkdir -p "$work/rv64"
    SALTIC_TARGET=rv64 build edges-rv64 \
        tests/edges.saltic \
        "$work/rv64/edges"
    SALTIC_TARGET=rv64 build always-rv64 \
        tests/always.saltic \
        "$work/rv64/always" \
        1048576
    measure run qemu-riscv64 -B 0x100000000 "$work/rv64/edges" >"$work/rv64/edges.txt"
    measure run qemu-riscv64 -B 0x100000000 "$work/rv64/always" >"$work/rv64/always.txt"
    diff -u tests/expected/edges.txt "$work/rv64/edges.txt"
    diff -u tests/expected/always.txt "$work/rv64/always.txt"
    SALTIC_TARGET=rv64 build canonical-rv64 \
        soul/canonical/main.saltic \
        "$work/rv64/canonical" \
        67108864
    cp tests/fixtures/input.txt "$work/rv64/input.txt"
    measure run qemu-riscv64 -B 0x100000000 "$work/rv64/canonical" \
        "$work/rv64/input.txt" "$work/rv64/output.txt" >"$work/rv64/canonical.txt"
    diff -u soul/canonical/expected/output.txt "$work/rv64/canonical.txt"
    test "$(<"$work/rv64/output.txt")" = "pip:0"
    echo "rv64: канон, edges и always под qemu-riscv64 — те же выводы, что у rv32i и x86_64"
}

test_rva23() {
    mkdir -p "$work/rva23"
    SALTIC_TARGET=x86_64 build rva23 \
        tests/rva23.saltic \
        "$work/rva23/program"
    measure run "$work/rva23/program" >"$work/rva23/lines.txt"
    python3 workbench/rva23/verify.py "$work/rva23/lines.txt"
    echo "rva23: кодировщик RV64 сошёлся с GNU-ассемблером на всех командах таблицы"
}

test_x86_encoder() {
    mkdir -p "$work/x86-encoder"
    SALTIC_TARGET=rv32i build x86-encoder-rv32i \
        tests/x86-encoder.saltic \
        "$work/x86-encoder/rv32i.elf"
    SALTIC_TARGET=x86_64 build x86-encoder-x86_64 \
        tests/x86-encoder.saltic \
        "$work/x86-encoder/x86_64"
    measure run qemu-riscv32 -B 0x100000000 "$work/x86-encoder/rv32i.elf" \
        >"$work/x86-encoder/rv32i.txt"
    measure run "$work/x86-encoder/x86_64" \
        >"$work/x86-encoder/x86_64.txt"
    diff -u tests/expected/x86-encoder.txt "$work/x86-encoder/rv32i.txt"
    diff -u tests/expected/x86-encoder.txt "$work/x86-encoder/x86_64.txt"
    echo "кодировщик x86-64: байты команд совпадают с GNU as — одинаково под rv32i и x86_64"
}

test_dict() {
    mkdir -p "$work/dict"
    SALTIC_TARGET=rv32i build dict-rv32i \
        tests/dict.saltic \
        "$work/dict/rv32i.elf"
    SALTIC_TARGET=x86_64 build dict-x86_64 \
        tests/dict.saltic \
        "$work/dict/x86_64"
    measure run qemu-riscv32 -B 0x100000000 "$work/dict/rv32i.elf" \
        >"$work/dict/rv32i.txt"
    measure run "$work/dict/x86_64" \
        >"$work/dict/x86_64.txt"
    diff -u tests/expected/dict.txt "$work/dict/rv32i.txt"
    diff -u tests/expected/dict.txt "$work/dict/x86_64.txt"
    echo "словарь: запись на месте, UnknownKey, вложенный навык, рост таблицы — одинаково под rv32i и x86_64"
}

test_platform() {
    mkdir -p "$work/platform"
    local target host_run
    for target in rv32i x86_64 x86_64-translation; do
        SALTIC_TARGET=$target build platform-$target tests/platform.saltic "$work/platform/$target"
        SALTIC_TARGET=$target build uncaught-$target tests/fixtures/uncaught.saltic "$work/platform/uncaught-$target"
        SALTIC_TARGET=$target build needs-args-$target tests/fixtures/needs-args.saltic "$work/platform/needs-args-$target"
        if [[ "$target" == rv32i ]]; then host_run=(qemu-riscv32 -B 0x100000000); else host_run=(); fi
        "${host_run[@]}" "$work/platform/$target" >"$work/platform/$target.txt"
        diff -u tests/expected/platform.txt "$work/platform/$target.txt"
        if "${host_run[@]}" "$work/platform/uncaught-$target" >"$work/platform/uncaught-$target.txt"; then
            echo "платформа: непойманная ошибка не стала кодом выхода ($target)" >&2
            return 1
        fi
        test "$(<"$work/platform/uncaught-$target.txt")" = "$(printf 'до ошибки\nошибка: Boom')"
        if "${host_run[@]}" "$work/platform/needs-args-$target" >"$work/platform/needs-args-$target.txt"; then
            echo "платформа: нехватка аргументов не стала кодом выхода ($target)" >&2
            return 1
        fi
        test "$(<"$work/platform/needs-args-$target.txt")" = "нужно 2 аргументов"
        test "$("${host_run[@]}" "$work/platform/needs-args-$target" раз два)" = "раз два"
    done
    echo "платформа: NotSupported ловится, непойманная ошибка и нехватка аргументов печатаются — одинаково под rv32i, x86_64 и x86_64-translation"
}

test_memory() {
    mkdir -p "$work/memory"
    build memory \
        soul/seed/tests/memory.saltic \
        "$work/memory/program.elf" \
        2097152
    run_built \
        "$work/memory/program.elf"
    echo "память: регионы освобождают мусор на куче 1 МБ"
}

test_native() {
    local target="${SALTIC_NATIVE_TARGET:-x86_64}"
    mkdir -p "$work/native"
    SALTIC_TARGET=$target build native-canonical \
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
    SALTIC_TARGET=$target build native-memory \
        soul/seed/tests/memory.saltic \
        "$work/native/memory" \
        2097152
    "$work/native/memory"
    SALTIC_TARGET=$target build native-deep \
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
    SALTIC_TARGET=$target build native-keys \
        tests/fixtures/keys.saltic \
        "$work/native/keys" \
        1048576
    test "$(printf 'a\t\177 z\nq' | "$work/native/keys")" = "[a][tab][backspace][ ][z][enter]"
    SALTIC_TARGET=$target build native-imports \
        tests/fixtures/imports.saltic \
        "$work/native/imports" \
        67108864
    test "$("$work/native/imports")" = "$(printf 'длина: 6\nпусто: yes\nстрок: 3\nфайл прочитан: yes\nбайт 259: ByteOutsideRange')"
    SALTIC_TARGET=$target build native-big-numbers \
        tests/fixtures/big-numbers.saltic \
        "$work/native/big-numbers" \
        1048576
    test "$("$work/native/big-numbers" | tr '\n' ' ')" = "-268435455 268435455 33554432 -33554433 100000000 33554431 -256 255 4096 -4097 200000001 268435455 "
    echo "x86-64 ($target): канон и память работают на родном процессоре, переполнение стека падает сразу, нажатия читаются, импорт работает, большие числа точны"
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
    tail -n 2 "$work/machine/testing-failure.txt" | head -n 1 \
        | grep -Fq -- '- контроль провала -> 1  [FAIL] (ожидалось 2)'
    tail -n 1 "$work/machine/testing-failure.txt" \
        | grep -Fqx 'ошибка: TestsFailed'
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

test_uefi_translation() {
    SALTIC_TARGET=x86_64-uefi-translation SALTIC_UEFI_DIR="$work/uefi-translation" bash os/target/uefi_x86_64/build.sh
    SALTIC_UEFI_DIR="$work/uefi-translation" bash os/target/uefi_x86_64/run.sh --check
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

test_panels() {
    mkdir -p "$work/panels"
    build panels \
        tests/panels.saltic \
        "$work/panels/program.elf"
    run_built \
        "$work/panels/program.elf"
    echo "panels: строки журнала и подписи системной панели подтверждены"
}

test_mrpc() {
    mkdir -p "$work/mrpc"
    build mrpc \
        tests/mrpc.saltic \
        "$work/mrpc/program.elf"
    run_built \
        "$work/mrpc/program.elf"
    echo "mrpc: запросы и ответы mRPC/1.0 агента подтверждены"
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
        groups) test_groups ;;
        bytes) test_bytes ;;
        edges) test_edges ;;
        always) test_always ;;
        rva23) test_rva23 ;;
        rv64) test_rv64 ;;
        x86-encoder) test_x86_encoder ;;
        dict) test_dict ;;
        seed-contract) test_seed_contract ;;
        machine) test_machine ;;
        abi) test_abi ;;
        memory) test_memory ;;
        platform) test_platform ;;
        native) test_native ;;
        native-translation) SALTIC_NATIVE_TARGET=x86_64-translation test_native ;;
        uefi-translation) test_uefi_translation ;;
        qemu-virt) test_qemu_virt ;;
        uefi) test_uefi ;;
        jtml) test_jtml ;;
        tasks) test_tasks ;;
        panels) test_panels ;;
        mrpc) test_mrpc ;;
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
    set -- qemu-virt uefi uefi-translation closure
elif [[ "$1" == "all" ]]; then
    set -- \
        checker \
        fixed-types \
        modules \
        json-rpc \
        diagnostics \
        groups \
        bytes \
        edges \
        always \
        rva23 \
        rv64 \
        x86-encoder \
        dict \
        seed-contract \
        machine \
        abi \
        memory \
        platform \
        native \
        native-translation \
        jtml \
        tasks \
        panels \
        mrpc
fi

for name in "$@"; do
    metrics_begin "$name"
    run_case "$name"
    metrics_end
done
metrics_report "$@" || echo "метрики: ⚠️ таблица не собралась, проверки это не затрагивает"
