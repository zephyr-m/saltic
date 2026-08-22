default:
    just --list

compile file="soul/seed/canonical/main.saltic" output="/tmp/saltic.elf":
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'bash os/bootstrap/build.sh {{file}} {{output}}'

run file="soul/seed/canonical/main.saltic" output="/tmp/saltic.elf" *args:
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'bash os/bootstrap/build.sh {{file}} {{output}} && qemu-riscv32 -B 0x100000000 {{output}} {{args}}'

qemu file="os/target/qemu_virt/smoke.saltic":
    mkdir -p .cache/build/qemu_virt
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'qemu-riscv32 -B 0x100000000 os/bootstrap/compiler.elf {{file}} .cache/build/qemu_virt/program.s && riscv32-none-elf-gcc -march=rv32i_zicsr -mabi=ilp32 -mno-relax -nostdlib -Wl,--no-relax,-T,os/target/qemu_virt/linker.ld,-Map,.cache/build/qemu_virt/program.map os/target/qemu_virt/platform.S .cache/build/qemu_virt/program.s -o .cache/build/qemu_virt/program.elf && qemu-system-riscv32 -machine virt -nographic -bios none -kernel .cache/build/qemu_virt/program.elf'

qemu-graphics:
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'bash os/target/qemu_virt/build-graphics.sh && qemu-system-riscv32 -machine virt -global virtio-mmio.force-legacy=false -device ramfb -device virtio-keyboard-device -display gtk -serial stdio -monitor none -bios none -kernel .cache/build/qemu-graphics/program.elf'

qemu-graphics-check:
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'bash os/target/qemu_virt/build-graphics.sh --check'

selfhost source="soul/seed/canonical/main.saltic" output="/tmp/saltic-self-parser.elf":
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'bash os/bootstrap/build.sh soul/seed/parser.saltic {{output}} && qemu-riscv32 -B 0x100000000 {{output}} {{source}}'

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
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'SALTIC_BUILD_DIR=.cache/build/tracer/build bash os/bootstrap/build.sh {{file}} .cache/build/tracer/target.elf .cache/build/tracer/target.s && SALTIC_HEAP_BYTES=536870912 SALTIC_BUILD_DIR=.cache/build/tracer/build bash os/bootstrap/build.sh soul/craft/tracer.saltic .cache/build/tracer/tracer.elf .cache/build/tracer/tracer.s && qemu-riscv32 -B 0x100000000 .cache/build/tracer/tracer.elf .cache/build/tracer/target.elf'

trace-elf file:
    mkdir -p .cache/build/tracer
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'SALTIC_HEAP_BYTES=536870912 SALTIC_BUILD_DIR=.cache/build/tracer/build bash os/bootstrap/build.sh soul/craft/tracer.saltic .cache/build/tracer/tracer.elf .cache/build/tracer/tracer.s && qemu-riscv32 -B 0x100000000 .cache/build/tracer/tracer.elf {{file}}'

bootstrap-parity:
    just test bootstrap

bootstrap-refresh source="soul/seed/toolchain.saltic":
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'bash os/bootstrap/refresh.sh {{source}}'

heap-audit source="soul/seed/toolchain.saltic":
    nix-shell -p qemu ripgrep pkgsCross.riscv32-embedded.buildPackages.gdb --run 'bash os/bootstrap/heap-audit.sh {{source}}'

toolchain-step:
    just checker
    just bootstrap-refresh
    just modules
    just bootstrap-parity

vm-step:
    just vm

test case="all":
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'bash tests/run.sh {{case}}'

verify: test
