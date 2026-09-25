set shell := ["bash", "-uc"]
set positional-arguments

default:
    just --list

compile file="soul/seed/canonical/main.saltic" output="/tmp/saltic.elf":
    SALTIC_DIRECT_ONLY=1 bash os/bootstrap/build.sh "$1" "$2"

run file="soul/seed/canonical/main.saltic" output="/tmp/saltic.elf" *args:
    SALTIC_DIRECT_ONLY=1 bash os/bootstrap/build.sh "$1" "$2"
    qemu-riscv32 -B 0x100000000 "$2" "${@:3}"

qemu file="os/target/qemu_virt/smoke.saltic":
    mkdir -p .cache/build/qemu_virt
    bash os/bootstrap/build.sh "$1" .cache/build/qemu_virt/program.elf

qemu-graphics:
    bash os/target/qemu_virt/build-graphics.sh

os port="46321":
    bash os/target/qemu_virt/build-graphics.sh

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

selfhost source="soul/seed/canonical/main.saltic" output="/tmp/saltic-self-parser.elf" json=".cache/build/pipeline/parsed.json":
    mkdir -p "$(dirname "$3")"
    bash os/bootstrap/build.sh soul/seed/parser.saltic "$2"
    qemu-riscv32 -B 0x100000000 "$2" "$1" "$3"

selfcheck input=".cache/build/pipeline/parsed.json" output="/tmp/saltic-self-checker.elf" json=".cache/build/pipeline/checked.json":
    mkdir -p "$(dirname "$3")"
    bash os/bootstrap/build.sh soul/seed/checker.saltic "$2"
    qemu-riscv32 -B 0x100000000 "$2" "$1" "$3"

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

bootstrap-parity:
    just test bootstrap

bootstrap-refresh source="soul/seed/toolchain.saltic":
    bash os/bootstrap/refresh.sh "$1"

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
