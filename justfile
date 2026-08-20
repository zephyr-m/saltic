default:
    just --list

parse file="canonical.s":
    node js/1-parser.js {{file}}

check file="canonical.s":
    node js/2-checker.js {{file}}

compile file="canonical.s" output="/tmp/saltic.elf":
    nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run 'node js/3-compiler.js {{file}} {{output}}'

run file="canonical.s" output="/tmp/saltic.elf" *args:
    nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run 'node js/3-compiler.js {{file}} {{output}}'
    node js/4-vm.js {{output}} -- {{args}}

selfhost source="canonical.s" output="/tmp/saltic-self-parser.elf":
    nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run 'node js/3-compiler.js s2/1-parser.s {{output}}'
    node js/4-vm.js {{output}} --steps 1000000000 -- {{source}}

compiler-parity:
    bash tests/4-compiler-parity.sh

vm-parity:
    bash tests/5-vm-parity.sh

selfhost-parity:
    bash tests/6-selfhost-parity.sh

test:
    bash tests/1-canonical.sh
    bash tests/2-selfhost-parser.sh
    bash tests/3-checker-parity.sh
    bash tests/4-compiler-parity.sh
    bash tests/5-vm-parity.sh

verify: test
