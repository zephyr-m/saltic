set shell := ["bash", "-uc"]
set positional-arguments

default:
    just --list

compile file="soul/seed/canonical/main.saltic" output="/tmp/saltic.elf":
    bash os/bootstrap/build.sh "$1" "$2"

run file="soul/seed/canonical/main.saltic" output="/tmp/saltic.elf" *args:
    bash os/bootstrap/build.sh "$1" "$2"
    qemu-riscv32 -B 0x100000000 "$2" "${@:3}"

qemu file="os/target/qemu_virt/smoke.saltic":
    mkdir -p .cache/build/qemu_virt
    qemu-riscv32 -B 0x100000000 os/bootstrap/compiler.elf "$1" .cache/build/qemu_virt/program.s
    riscv32-none-elf-gcc -march=rv32i_zicsr -mabi=ilp32 -mno-relax -nostdlib -Wl,--no-relax,-T,os/target/qemu_virt/linker.ld,-Map,.cache/build/qemu_virt/program.map os/target/qemu_virt/platform.S .cache/build/qemu_virt/program.s -o .cache/build/qemu_virt/program.elf
    qemu-system-riscv32 -machine virt -nographic -bios none -kernel .cache/build/qemu_virt/program.elf

qemu-graphics:
    bash os/target/qemu_virt/build-graphics.sh
    qemu-system-riscv32 -machine virt -global virtio-mmio.force-legacy=false -device ramfb -device virtio-keyboard-device -display gtk -serial stdio -monitor none -bios none -kernel .cache/build/qemu-graphics/program.elf

os port="46321":
    bash os/target/qemu_virt/build-graphics.sh
    qemu-system-riscv32 -machine virt -global virtio-mmio.force-legacy=false -device ramfb -device virtio-keyboard-device -display gtk -serial tcp:127.0.0.1:"$1",server=on,wait=off -monitor none -bios none -kernel .cache/build/qemu-graphics/program.elf

os-send command port="46321":
    #!/usr/bin/env bash
    set -euo pipefail
    exec 3<>/dev/tcp/127.0.0.1/"$2"
    printf '%s\n' "$1" >&3
    if ! IFS= read -r -t 5 response <&3; then
        echo "Saltic не ответил за 5 секунд" >&2
        exit 1
    fi
    printf '%s\n' "$response"

qemu-graphics-check:
    bash os/target/qemu_virt/build-graphics.sh --check

selfhost source="soul/seed/canonical/main.saltic" output="/tmp/saltic-self-parser.elf":
    bash os/bootstrap/build.sh soul/seed/parser.saltic "$2"
    qemu-riscv32 -B 0x100000000 "$2" "$1"

checker:
    just test checker

vm:
    just test vm

fixed-types:
    just test fixed-types

modules:
    just test modules

json-rpc:
    just test json-rpc

diagnostics:
    just test diagnostics

seed-contract:
    just test seed-contract

machine:
    just test machine

abi:
    just test abi

trace file="soul/seed/canonical/main.saltic":
    mkdir -p .cache/build/tracer
    SALTIC_BUILD_DIR=.cache/build/tracer/build bash os/bootstrap/build.sh "$1" .cache/build/tracer/target.elf .cache/build/tracer/target.s
    SALTIC_HEAP_BYTES=536870912 SALTIC_BUILD_DIR=.cache/build/tracer/build bash os/bootstrap/build.sh soul/craft/tracer.saltic .cache/build/tracer/tracer.elf .cache/build/tracer/tracer.s
    qemu-riscv32 -B 0x100000000 .cache/build/tracer/tracer.elf .cache/build/tracer/target.elf

trace-elf file:
    mkdir -p .cache/build/tracer
    SALTIC_HEAP_BYTES=536870912 SALTIC_BUILD_DIR=.cache/build/tracer/build bash os/bootstrap/build.sh soul/craft/tracer.saltic .cache/build/tracer/tracer.elf .cache/build/tracer/tracer.s
    qemu-riscv32 -B 0x100000000 .cache/build/tracer/tracer.elf "$1"

native-trace assembly=".cache/build/bootstrap-refresh/stage-3/toolchain.s" source="soul/seed/toolchain.saltic":
    #!/usr/bin/env bash
    set -euo pipefail
    work=".cache/build/native-trace"
    mkdir -p "$work/build"
    SALTIC_HEAP_BYTES=536870912 SALTIC_BUILD_DIR="$work/build" \
        bash os/bootstrap/build.sh \
        'toolbox(raw)/native-tracer.saltic' \
        "$work/tracer.elf" \
        "$work/tracer.s"
    if ! grep -q '^rt_alloc:$' "$1"; then
        echo "нативная трассировка: распределитель памяти не найден" >&2
        exit 1
    fi
    if ! grep -q '^rt_out_of_memory:$' "$1"; then
        echo "нативная трассировка: обработчик исчерпания памяти не найден" >&2
        exit 1
    fi
    if ! grep -q '^\.space 16777216$' "$1"; then
        echo "нативная трассировка: стандартная куча не найдена" >&2
        exit 1
    fi
    qemu-riscv32 -B 4294967296 \
        "$work/tracer.elf" support "$1" "$work/support.s"
    sed \
        -e '/^\.section \.text$/a\  .include ".cache/build/native-trace/support.s"' \
        -e '/^rt_alloc:$/a\  SALTIC_NATIVE_TRACE_ALLOC_HOOK' \
        -e '/^rt_out_of_memory:$/a\  SALTIC_NATIVE_TRACE_FAILURE_HOOK' \
        -e 's/^\.space 16777216$/.space 536870912/' \
        "$1" >"$work/instrumented.s"
    riscv32-none-elf-as -march=rv32i -mabi=ilp32 \
        os/bootstrap/linux-memory.S -o "$work/linux-memory.o"
    riscv32-none-elf-as -march=rv32i -mabi=ilp32 \
        "$work/instrumented.s" -o "$work/instrumented.o"
    riscv32-none-elf-gcc \
        -march=rv32i -mabi=ilp32 -mno-relax -nostdlib \
        -Wl,--no-relax,--section-start=.saltic_low_memory=4096,-Ttext=65536,-e,_start \
        "$work/linux-memory.o" "$work/instrumented.o" \
        -o "$work/instrumented.elf"
    set +e
    qemu-riscv32 -B 4294967296 \
        "$work/instrumented.elf" "$2" "$work/output.s" \
        >"$work/stdout.txt" 2>"$work/trace.bin"
    status=$?
    set -e
    echo "нативная трассировка: целевая программа завершилась с кодом $status"
    qemu-riscv32 -B 4294967296 \
        "$work/tracer.elf" render "$work/instrumented.elf" "$work/trace.bin"

bootstrap-parity:
    just test bootstrap

bootstrap-refresh source="soul/seed/toolchain.saltic":
    bash os/bootstrap/refresh.sh "$1"

bootstrap-rescue assembly=".cache/build/bootstrap-refresh/stage-3/toolchain.s":
    SALTIC_BOOTSTRAP_RESCUE_ASSEMBLY="$1" SALTIC_BOOTSTRAP_REFRESH_HEAP_BYTES=4026531840 bash os/bootstrap/refresh.sh

toolchain-step:
    just checker
    just bootstrap-refresh
    just modules
    just bootstrap-parity

vm-step:
    just vm

test case="all":
    bash tests/run.sh "$1"

package:
    bash .github/package.sh

clean:
    rm -rf -- .cache/build .cache/dist

verify: test
