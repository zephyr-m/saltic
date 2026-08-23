#!/usr/bin/env bash
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

build() {
    local name="$1"
    local source="$2"
    local output="$3"
    local heap_bytes="${4:-16777216}"

    SALTIC_BUILD_DIR="$work/build/$name" \
    SALTIC_HEAP_BYTES="$heap_bytes" \
    bash os/bootstrap/build.sh "$source" "$output"
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
    qemu-riscv32 -B 0x100000000 "$checker_elf" \
        soul/seed/canonical/main.saltic >"$work/checker/canonical.txt"
    qemu-riscv32 -B 0x100000000 "$checker_elf" \
        soul/seed/canonical/errors.saltic >"$work/checker/errors.txt"
    qemu-riscv32 -B 0x100000000 "$checker_elf" \
        soul/seed/canonical/support.saltic >>"$work/checker/errors.txt"

    test ! -s "$work/checker/canonical.txt"
    diff -u \
        soul/seed/canonical/expected/errors.txt \
        "$work/checker/errors.txt"
    echo "чекер: нативная проверка пройдена"
}

test_vm() {
    mkdir -p "$work/vm"
    riscv32-none-elf-gcc \
        -march=rv32i -mabi=ilp32 -mno-relax -nostdlib \
        -Wl,--no-relax,-Ttext=0x10000,-e,_start \
        tests/fixtures/vm-canonical.S \
        -o "$work/vm/canonical.elf"
    riscv32-none-elf-objcopy \
        -O binary \
        "$work/vm/canonical.elf" \
        "$work/vm/canonical.bin"

    build vm tests/vm.saltic "$work/vm/vm.elf" 536870912
    qemu-riscv32 -B 0x100000000 "$work/vm/vm.elf" \
        "$work/vm/canonical.elf" \
        "$work/vm/canonical.bin" \
        tests/fixtures/input.txt \
        "$work/vm/actual.txt"

    diff -u tests/expected/vm.txt "$work/vm/actual.txt"
    echo "VM: нативная проверка пройдена"
}

test_fixed_types() {
    mkdir -p "$work/fixed-types"
    build_checker
    qemu-riscv32 -B 0x100000000 "$checker_elf" \
        soul/seed/tests/fixed.saltic \
        >"$work/fixed-types/valid-diagnostics.txt"
    qemu-riscv32 -B 0x100000000 "$checker_elf" \
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
    qemu-riscv32 -B 0x100000000 \
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
    qemu-riscv32 -B 0x100000000 "$checker_elf" \
        tests/fixtures/modules/main.saltic \
        >"$work/modules/main-diagnostics.txt"
    qemu-riscv32 -B 0x100000000 "$checker_elf" \
        tests/fixtures/modules/errors.saltic \
        >"$work/modules/errors.txt"

    test ! -s "$work/modules/main-diagnostics.txt"
    diff -u \
        tests/expected/module-errors.txt \
        "$work/modules/errors.txt"

    build modules \
        tests/fixtures/modules/main.saltic \
        "$work/modules/program.elf"
    qemu-riscv32 -B 0x100000000 \
        "$work/modules/program.elf" \
        >"$work/modules/stdout.txt"
    diff -u tests/expected/modules.txt "$work/modules/stdout.txt"
    echo "модули: нативная проверка пройдена"
}

test_json_rpc() {
    mkdir -p "$work/json-rpc"
    build json-rpc tests/json-rpc.saltic "$work/json-rpc/program.elf"
    qemu-riscv32 -B 0x100000000 \
        "$work/json-rpc/program.elf" \
        >"$work/json-rpc/stdout.txt"
    diff -u tests/expected/json-rpc.txt "$work/json-rpc/stdout.txt"
    echo "json-rpc: ok"
}

test_tracer() {
    mkdir -p "$work/tracer"
    SALTIC_BUILD_DIR="$work/build/tracer" \
    bash os/bootstrap/build.sh \
        tests/tracer.saltic \
        "$work/tracer/target.elf" \
        "$work/tracer/target.s"
    SALTIC_HEAP_BYTES=536870912 \
    SALTIC_BUILD_DIR="$work/build/tracer" \
    bash os/bootstrap/build.sh \
        soul/craft/tracer.saltic \
        "$work/tracer/tracer.elf" \
        "$work/tracer/tracer.s"
    qemu-riscv32 -B 0x100000000 \
        "$work/tracer/tracer.elf" \
        "$work/tracer/target.elf" \
        >"$work/tracer/stdout.txt"

    sed -E \
        -e "s|$work/tracer/target.elf|<target.elf>|" \
        -e 's/0x[0-9a-f]{8} \(("[^"]*"|группа|объект)\)/<адрес> (\1)/g' \
        "$work/tracer/stdout.txt" \
        >"$work/tracer/normalized.txt"
    diff -u tests/expected/tracer.txt "$work/tracer/normalized.txt"
    echo "трассер: ок"
}

test_diagnostics() {
    mkdir -p "$work/diagnostics"
    build diagnostics \
        tests/diagnostics.saltic \
        "$work/diagnostics/program.elf"
    qemu-riscv32 -B 0x100000000 \
        "$work/diagnostics/program.elf" \
        >"$work/diagnostics/stdout.txt"
    diff -u \
        tests/expected/diagnostics.txt \
        "$work/diagnostics/stdout.txt"
    echo "диагностика: всё согласовано"
}

test_seed_contract() {
    mkdir -p "$work/seed-contract"
    build seed-contract \
        soul/seed/tests/contract.saltic \
        "$work/seed-contract/program.elf"
    qemu-riscv32 -B 0x100000000 \
        "$work/seed-contract/program.elf" \
        >"$work/seed-contract/stdout.txt"
    diff -u \
        soul/seed/tests/expected/contract.txt \
        "$work/seed-contract/stdout.txt"
    echo "seed: единый контракт подтверждён"
}

test_machine() {
    mkdir -p "$work/machine"
    build machine \
        soul/seed/tests/machine.saltic \
        "$work/machine/program.elf"
    qemu-riscv32 -B 0x100000000 \
        "$work/machine/program.elf"
    echo "машина: кодирование и образ подтверждены"
}

test_abi() {
    mkdir -p "$work/abi"
    build abi \
        soul/seed/tests/abi.saltic \
        "$work/abi/program.elf"
    qemu-riscv32 -B 0x100000000 \
        "$work/abi/program.elf" \
        >"$work/abi/stdout.txt"
    diff -u \
        soul/seed/tests/expected/abi.txt \
        "$work/abi/stdout.txt"
    echo "ABI: единый контракт подтверждён"
}

test_qemu_virt() {
    SALTIC_QEMU_GRAPHICS_DIR="$work/qemu-virt" \
        bash os/target/qemu_virt/build-graphics.sh --check
}

test_bootstrap() {
    local bootstrap_work="$work/bootstrap"
    local heap_bytes=536870912
    mkdir -p \
        "$bootstrap_work/stage-1" \
        "$bootstrap_work/stage-2" \
        "$bootstrap_work/canonical"

    echo "bootstrap: зафиксированный компилятор собирает toolchain"
    SALTIC_BUILD_DIR="$bootstrap_work/stage-1" \
    SALTIC_HEAP_BYTES="$heap_bytes" \
    bash os/bootstrap/build.sh \
        soul/seed/toolchain.saltic \
        "$bootstrap_work/stage-1/toolchain.elf" \
        "$bootstrap_work/stage-1/toolchain.s"

    echo "bootstrap: сравниваю исполняемый образ с зафиксированным компилятором"
    riscv32-none-elf-objcopy \
        -O binary -j .text -j .rodata \
        os/bootstrap/compiler.elf \
        "$bootstrap_work/stage-1/bootstrap.bin"
    riscv32-none-elf-objcopy \
        -O binary -j .text -j .rodata \
        "$bootstrap_work/stage-1/toolchain.elf" \
        "$bootstrap_work/stage-1/toolchain.bin"
    cmp \
        "$bootstrap_work/stage-1/bootstrap.bin" \
        "$bootstrap_work/stage-1/toolchain.bin"

    echo "bootstrap: собранный toolchain повторяет себя"
    SALTIC_BOOTSTRAP_COMPILER="$bootstrap_work/stage-1/toolchain.elf" \
    SALTIC_BUILD_DIR="$bootstrap_work/stage-2" \
    SALTIC_HEAP_BYTES="$heap_bytes" \
    bash os/bootstrap/build.sh \
        soul/seed/toolchain.saltic \
        "$bootstrap_work/stage-2/toolchain.elf" \
        "$bootstrap_work/stage-2/toolchain.s"
    diff -u \
        "$bootstrap_work/stage-1/toolchain.s" \
        "$bootstrap_work/stage-2/toolchain.s"
    cmp \
        "$bootstrap_work/stage-1/toolchain.elf" \
        "$bootstrap_work/stage-2/toolchain.elf"

    echo "bootstrap: собранный toolchain компилирует канон"
    SALTIC_BOOTSTRAP_COMPILER="$bootstrap_work/stage-2/toolchain.elf" \
    SALTIC_BUILD_DIR="$bootstrap_work/canonical" \
    bash os/bootstrap/build.sh \
        soul/seed/canonical/main.saltic \
        "$bootstrap_work/canonical/canonical.elf" \
        "$bootstrap_work/canonical/canonical.s"
    cp tests/fixtures/input.txt "$bootstrap_work/canonical/input.txt"
    qemu-riscv32 -B 0x100000000 \
        "$bootstrap_work/canonical/canonical.elf" \
        "$bootstrap_work/canonical/input.txt" \
        "$bootstrap_work/canonical/output.txt" \
        >"$bootstrap_work/canonical/stdout.txt"
    diff -u \
        soul/seed/canonical/expected/output.txt \
        "$bootstrap_work/canonical/stdout.txt"
    test "$(<"$bootstrap_work/canonical/output.txt")" = "pip:0"
    echo "bootstrap: ok"
}

run_case() {
    case "$1" in
        checker) test_checker ;;
        vm) test_vm ;;
        fixed-types) test_fixed_types ;;
        modules) test_modules ;;
        json-rpc) test_json_rpc ;;
        tracer) test_tracer ;;
        diagnostics) test_diagnostics ;;
        seed-contract) test_seed_contract ;;
        machine) test_machine ;;
        abi) test_abi ;;
        qemu-virt) test_qemu_virt ;;
        bootstrap) test_bootstrap ;;
        *)
            echo "неизвестная проверка: $1" >&2
            exit 2
            ;;
    esac
}

if (( $# == 0 )); then
    set -- all
fi

if [[ "$1" == "all" ]]; then
    set -- \
        checker \
        vm \
        fixed-types \
        modules \
        json-rpc \
        tracer \
        diagnostics \
        seed-contract \
        machine \
        abi \
        qemu-virt \
        bootstrap
fi

for name in "$@"; do
    run_case "$name"
done
