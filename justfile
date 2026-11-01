set shell := ["bash", "-uc"]
set positional-arguments

default:
    just --list

playground:
    node os/ui/playground/server.mjs

compile file="soul/canonical/main.saltic" output="/tmp/saltic.elf":
    bash bootstrap/build.sh "$1" "$2"

run file="soul/canonical/main.saltic" output="/tmp/saltic.elf" *args:
    bash bootstrap/build.sh "$1" "$2"
    nix --extra-experimental-features "nix-command flakes" develop --command qemu-riscv32 -B 0x100000000 "$2" "${@:3}"

native file="soul/canonical/main.saltic" output="/tmp/saltic-native" *args:
    SALTIC_TARGET=x86_64 bash bootstrap/build.sh "$1" "$2"
    "$2" "${@:3}"

qemu file="os/target/qemu_virt/smoke.saltic":
    mkdir -p .cache/build/qemu_virt
    bash bootstrap/build.sh "$1" .cache/build/qemu_virt/program.elf

qemu-graphics:
    nix --extra-experimental-features "nix-command flakes" develop --command bash -c 'bash os/target/qemu_virt/build-graphics.sh && qemu-system-riscv32 -machine virt -global virtio-mmio.force-legacy=false -device ramfb -device virtio-keyboard-device -device virtio-tablet-device -audiodev pipewire,id=saltic_audio -device virtio-sound-device,audiodev=saltic_audio -display gtk -serial stdio -monitor none -bios none -kernel .cache/build/qemu-graphics/program.elf'

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

trace file="soul/canonical/main.saltic":
    mkdir -p .cache/build/tracer
    SALTIC_BUILD_DIR=.cache/build/tracer/build bash bootstrap/build.sh "$1" .cache/build/tracer/target.elf
    SALTIC_HEAP_BYTES=536870912 SALTIC_BUILD_DIR=.cache/build/tracer/build bash bootstrap/build.sh soul/craft/tracer.saltic .cache/build/tracer/tracer.elf
    qemu-riscv32 -B 0x100000000 .cache/build/tracer/tracer.elf .cache/build/tracer/target.elf

trace-elf file:
    mkdir -p .cache/build/tracer
    SALTIC_HEAP_BYTES=536870912 SALTIC_BUILD_DIR=.cache/build/tracer/build bash bootstrap/build.sh soul/craft/tracer.saltic .cache/build/tracer/tracer.elf
    qemu-riscv32 -B 0x100000000 .cache/build/tracer/tracer.elf "$1"

bootstrap-refresh source="soul/seed/selfhost/toolchain.saltic":
    bash bootstrap/refresh.sh "$1"

global-check:
    bash workbench/global-check.sh

hosts:
    bash workbench/hosts.sh

test case="all":
    nix --extra-experimental-features "nix-command flakes" develop --command bash tests/run.sh "$1"

package:
    bash .github/package.sh

clean:
    rm -rf -- .cache/build .cache/dist
