default:
    just --list

parse file="canonical.saltic":
    node js/1-parser.js {{file}}

check file="canonical.saltic":
    node js/2-checker.js {{file}}

compile file="canonical.saltic" output="/tmp/saltic.elf":
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'bash bootstrap/build.sh {{file}} {{output}}'

js-compile file="canonical.saltic" output="/tmp/saltic-js.elf":
    nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run 'node js/3-compiler.js {{file}} {{output}}'

run file="canonical.saltic" output="/tmp/saltic.elf" *args:
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'bash bootstrap/build.sh {{file}} {{output}} && qemu-riscv32 -B 0x100000000 {{output}} {{args}}'

js-run file="canonical.saltic" output="/tmp/saltic-js.elf" *args:
    nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run 'node js/3-compiler.js {{file}} {{output}}'
    node js/4-vm.js {{output}} -- {{args}}

qemu file="examples/qemu-hello.saltic":
    mkdir -p .cache/build/qemu-virt
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'qemu-riscv32 -B 0x100000000 bootstrap/compiler.elf {{file}} .cache/build/qemu-virt/program.s && riscv32-none-elf-gcc -march=rv32i_zicsr -mabi=ilp32 -mno-relax -nostdlib -Wl,--no-relax,-T,targets/qemu-virt/linker.ld,-Map,.cache/build/qemu-virt/program.map targets/qemu-virt/platform.S .cache/build/qemu-virt/program.s -o .cache/build/qemu-virt/program.elf && qemu-system-riscv32 -machine virt -nographic -bios none -kernel .cache/build/qemu-virt/program.elf'

qemu-graphics:
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'bash targets/qemu-virt/build-graphics.sh && qemu-system-riscv32 -machine virt -global virtio-mmio.force-legacy=false -device ramfb -device virtio-keyboard-device -display gtk -serial stdio -monitor none -bios none -kernel .cache/build/qemu-graphics/program.elf'

selfhost source="canonical.saltic" output="/tmp/saltic-self-parser.elf":
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'bash bootstrap/build.sh s2/parser.saltic {{output}} && qemu-riscv32 -B 0x100000000 {{output}} {{source}}'

js-selfhost source="canonical.saltic" output="/tmp/saltic-js-self-parser.elf":
    nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run 'node js/3-compiler.js s2/parser.saltic {{output}}'
    node js/4-vm.js {{output}} --steps 1000000000 -- {{source}}

compiler-parity:
    bash tests/4-compiler-parity.sh

vm-parity:
    bash tests/5-vm-parity.sh

fixed-types:
    bash tests/7-fixed-types.sh

modules:
    bash tests/8-modules.sh

json-rpc:
    bash tests/10-json-rpc.sh

trace file="canonical.saltic":
    mkdir -p .cache/build/tracer
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'SALTIC_BUILD_DIR=.cache/build/tracer/build bash bootstrap/build.sh {{file}} .cache/build/tracer/target.elf .cache/build/tracer/target.s && SALTIC_HEAP_BYTES=536870912 SALTIC_BUILD_DIR=.cache/build/tracer/build bash bootstrap/build.sh s2/craft/tracer.saltic .cache/build/tracer/tracer.elf .cache/build/tracer/tracer.s && qemu-riscv32 -B 0x100000000 .cache/build/tracer/tracer.elf .cache/build/tracer/target.elf'

trace-elf file:
    mkdir -p .cache/build/tracer
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'SALTIC_HEAP_BYTES=536870912 SALTIC_BUILD_DIR=.cache/build/tracer/build bash bootstrap/build.sh s2/craft/tracer.saltic .cache/build/tracer/tracer.elf .cache/build/tracer/tracer.s && qemu-riscv32 -B 0x100000000 .cache/build/tracer/tracer.elf {{file}}'

selfhost-parity:
    bash tests/6-selfhost-parity.sh

bootstrap-parity:
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'bash tests/9-bootstrap.sh'

bootstrap-refresh source="s2/toolchain.saltic":
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'bash bootstrap/refresh.sh {{source}}'

toolchain-step:
    node js/2-checker.js s2/parser.saltic >/dev/null
    bash tests/2-selfhost-parser.sh
    bash tests/3-checker-parity.sh
    just bootstrap-refresh
    bash tests/4-compiler-parity.sh
    bash tests/8-modules.sh
    just bootstrap-parity

vm-step:
    node js/2-checker.js s2/vm.saltic >/dev/null
    bash tests/5-vm-parity.sh

test:
    bash tests/1-canonical.sh
    bash tests/2-selfhost-parser.sh
    bash tests/3-checker-parity.sh
    bash tests/4-compiler-parity.sh
    bash tests/5-vm-parity.sh
    bash tests/6-selfhost-parity.sh
    bash tests/7-fixed-types.sh
    bash tests/8-modules.sh
    bash tests/10-json-rpc.sh
    bash tests/11-tracer.sh
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'bash tests/9-bootstrap.sh'

verify: test
