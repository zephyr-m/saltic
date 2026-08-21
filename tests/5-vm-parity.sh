#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
work=".cache/build/vm-parity"
mkdir -p "$work/bootstrap" "$work/guest" "$work/expected" "$work/actual" "$work/diff"

echo "сравнение VM: проверяю интерфейс"
if ! grep -q '^skill vm_run(image, options)' s2/4-vm.saltic; then
    echo "сравнение VM: в s2/4-vm.saltic ещё нет skill vm_run(image, options)"
    exit 1
fi

echo "сравнение VM: собираю комплексную RV32I-программу"
nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run \
    "riscv32-none-elf-gcc -march=rv32i -mabi=ilp32 -mno-relax -nostdlib -Wl,--no-relax,-Ttext=0x10000,-e,_start tests/fixtures/vm-canonical.S -o '$work/guest/vm-canonical.elf'"
nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run \
    "riscv32-none-elf-objcopy -O binary '$work/guest/vm-canonical.elf' '$work/guest/vm-canonical.bin'"
echo "сравнение VM: создаю $work/bootstrap/vm.saltic"
node tests/vm-parity.js build "$work/bootstrap/vm.saltic" \
    "$work/guest/vm-canonical.elf" "$work/guest/vm-canonical.bin" tests/fixtures/input.txt
node js/1-parser.js "$work/bootstrap/vm.saltic" >"$work/bootstrap/ast.json"
node js/2-checker.js "$work/bootstrap/vm.saltic" >"$work/bootstrap/checker.json"

echo "сравнение VM: собираю Saltic-VM"
nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc --run \
    "node js/3-compiler.js --assembly '$work/bootstrap/vm-rv32i.s' '$work/bootstrap/vm.saltic' '$work/bootstrap/vm.elf'"

scenarios=(
    "elf-normal|нормальное исполнение ELF|elf|normal"
    "flat-normal|нормальное исполнение плоского образа|bin|normal"
    "break|остановка EBREAK|elf|break"
    "illegal|неизвестная инструкция|elf|illegal"
    "misaligned-pc|невыровненный адрес инструкции|elf|pc"
    "load-fault|ошибка чтения памяти|elf|load"
    "store-fault|ошибка записи памяти|elf|store"
    "unsupported-ecall|неподдерживаемый системный вызов|elf|unsupported"
    "step-limit|превышение лимита шагов|elf|timeout"
)

for spec in "${scenarios[@]}"; do
    IFS='|' read -r name label format scenario <<<"$spec"
    image="$work/guest/vm-canonical.$format"
    expected="$work/expected/$name.txt"
    actual="$work/actual/$name.txt"
    difference="$work/diff/$name.diff"
    scenario_root="$work/expected/$name-root"

    echo "сравнение VM: $label"
    node tests/vm-parity.js expected \
        "$image" "$scenario" tests/fixtures/input.txt "$scenario_root" "$expected"
    node js/4-vm.js "$work/bootstrap/vm.elf" --steps 1000000000 -- \
        "$format" "$scenario" "$actual" \
        >"$work/actual/$name.runner.stdout" 2>"$work/actual/$name.runner.stderr"

    if ! diff -u "$expected" "$actual" >"$difference"; then
        echo "сравнение VM: найдено расхождение, смотри $difference"
        exit 1
    fi
done

echo "сравнение VM: всё совпало"
