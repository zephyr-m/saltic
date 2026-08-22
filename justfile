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

os:
    just qemu-graphics

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
