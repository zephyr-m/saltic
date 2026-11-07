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

bootstrap-refresh source="soul/seed/selfhost/toolchain.saltic":
    bash bootstrap/refresh.sh "$1"

global-check:
    bash workbench/global-check.sh

limits:
    SALTIC_TARGET=x86_64 bash bootstrap/build.sh workbench/limits.saltic .cache/build/workbench/limits
    .cache/build/workbench/limits

hosts:
    SALTIC_TARGET=x86_64 bash bootstrap/build.sh workbench/hosts.saltic .cache/build/workbench/hosts
    .cache/build/workbench/hosts

rv64:
    SALTIC_TARGET=x86_64 bash bootstrap/build.sh bootstrap/refresh-rv64.saltic .cache/build/workbench/refresh-rv64 >/dev/null
    .cache/build/workbench/refresh-rv64 ""

release-draft base="":
    SALTIC_TARGET=x86_64 bash bootstrap/build.sh workbench/release-draft.saltic .cache/build/workbench/release-draft >/dev/null
    .cache/build/workbench/release-draft "$1"

same-source:
    SALTIC_TARGET=x86_64 bash bootstrap/build.sh workbench/same-source.saltic .cache/build/workbench/same-source-check >/dev/null
    .cache/build/workbench/same-source-check

x86-golden mode="":
    SALTIC_TARGET=x86_64 bash bootstrap/build.sh workbench/x86-encoder-golden.saltic .cache/build/workbench/x86-encoder-golden >/dev/null
    .cache/build/workbench/x86-encoder-golden "$1"

same *sources:
    SALTIC_TARGET=x86_64 bash bootstrap/build.sh workbench/same.saltic .cache/build/workbench/same-check >/dev/null
    .cache/build/workbench/same-check "$*"

test case="all":
    nix --extra-experimental-features "nix-command flakes" develop --command bash tests/run.sh "$1"

package:
    bash .github/package.sh

clean:
    rm -rf -- .cache/build .cache/dist
