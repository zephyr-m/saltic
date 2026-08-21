default:
    just --list

parse file="canonical.saltic":
    node js/1-parser.js {{file}}

check file="canonical.saltic":
    node js/2-checker.js {{file}}

compile file="canonical.saltic" output="/tmp/saltic.elf":
    nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run 'node js/3-compiler.js {{file}} {{output}}'

run file="canonical.saltic" output="/tmp/saltic.elf" *args:
    nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run 'node js/3-compiler.js {{file}} {{output}}'
    node js/4-vm.js {{output}} -- {{args}}

qemu file="examples/qemu-hello.saltic":
    mkdir -p .cache/build/qemu-virt
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'node js/3-compiler.js --assembly .cache/build/qemu-virt/program.s {{file}} .cache/build/qemu-virt/program-vm.elf && riscv32-none-elf-gcc -march=rv32i_zicsr -mabi=ilp32 -mno-relax -nostdlib -Wl,--no-relax,-T,targets/qemu-virt/linker.ld,-Map,.cache/build/qemu-virt/program.map targets/qemu-virt/platform.S .cache/build/qemu-virt/program.s -o .cache/build/qemu-virt/program.elf && qemu-system-riscv32 -machine virt -nographic -bios none -kernel .cache/build/qemu-virt/program.elf'

qemu-graphics:
    nix-shell -p qemu pkgsCross.riscv32-embedded.buildPackages.gcc --run 'bash targets/qemu-virt/build-graphics.sh && qemu-system-riscv32 -machine virt -global virtio-mmio.force-legacy=false -device ramfb -device virtio-keyboard-device -display gtk -serial stdio -monitor none -bios none -kernel .cache/build/qemu-graphics/program.elf'

selfhost source="canonical.saltic" output="/tmp/saltic-self-parser.elf":
    nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run 'node js/3-compiler.js s2/1-parser.saltic {{output}}'
    node js/4-vm.js {{output}} --steps 1000000000 -- {{source}}

compiler-parity:
    bash tests/4-compiler-parity.sh

vm-parity:
    bash tests/5-vm-parity.sh

fixed-types:
    bash tests/7-fixed-types.sh

selfhost-parity:
    bash tests/6-selfhost-parity.sh

test:
    bash tests/1-canonical.sh
    bash tests/2-selfhost-parser.sh
    bash tests/3-checker-parity.sh
    bash tests/4-compiler-parity.sh
    bash tests/5-vm-parity.sh
    bash tests/6-selfhost-parity.sh
    bash tests/7-fixed-types.sh

verify: test
