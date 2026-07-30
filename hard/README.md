# Saltic CPU

Минимальное синтезируемое ядро для проверки аппаратного пути Saltic.

Это 32-битный стековый процессор с 16-битной инструкцией: старший байт — операция, младший — аргумент. Сейчас есть `push`, арифметика, сравнение, переходы, операции стека, `show` и `halt`.

```text
01 nn  push nn
02 00  add
03 00  sub
04 00  mul
05 00  eq
06 00  lt
07 nn  jump nn
08 nn  jz nn
09 00  dup
0a 00  drop
0b 00  show
ff 00  halt
```

Проверка через Verilator:

```bash
verilator --binary --timing --top cpu_test hard/cpu.sv hard/cpu_test.sv
./obj_dir/Vcpu_test
```

Следующий шаг — генерировать эти инструкции из AST Saltic, а затем синтезировать то же ядро под конкретную FPGA.

## Minsky core

`minsky.sv` — радикально минимальное ядро с двумя счётчиками и только двумя действиями:

```text
up counter, next
down counter, next, zero
```

`down` проверяет счётчик: при нуле переходит на `zero`, иначе вычитает единицу и переходит на `next`. Адрес `ff` останавливает машину.

```bash
verilator --binary --timing --top minsky_test hard/minsky.sv hard/minsky_test.sv
./obj_dir/Vminsky_test
```

## Interaction experiment

`sort.mjs` проверяет сортировку без общей памяти: каждый агент владеет одним числом и меняет только собственное состояние после локального handshake с соседом.

```bash
node hard/sort.mjs
```

Та же модель на Saltic:

```bash
racket racket/bootstrap/4-vm.rkt hard/sort.s
```

Неизменное вычисление при разной и меняющейся свободной массе:

```bash
racket racket/bootstrap/4-vm.rkt hard/mass-sort.s
```

## Logos

`LOGOS_SPEC.md` фиксирует Logos v0: 66-битный стикер, команды `NOP/INC/DEC/HALT`, 64-битный счётчик, таблицу реакций и lossless `valid/ready` handshake.

`logos.sv` — синтезируемая реализация одной клетки. `logos_vm.py` — независимая эталонная VM, `logos-v0.s` — модель на S. `logos-v0.csv` фиксирует общую тактовую трассу. `logos_test.sv` проверяет арифметику, zero-ветку, сохранение данных, остановку и backpressure.

```bash
verilator --binary --timing --top logos_test hard/logos.sv hard/logos_test.sv
./obj_dir/Vlogos_test
```

Эталонная VM и модель S:

```bash
python3 hard/logos_vm.py
racket racket/bootstrap/4-vm.rkt hard/logos-v0.s
```

## Fixed Logos addition protocol

Two unmodified Logos cells calculate `5+3=8` by exchanging only `DEC`, `INC`
and `HALT` stickers. The Python run prints every transfer; the RTL test applies
the same configuration directly to two `logos_cell` instances.

```bash
python3 hard/logos_add.py
verilator --binary --timing --top logos_add_test hard/logos.sv hard/logos_add_test.sv
./obj_dir/Vlogos_add_test
```

The abandoned Lafont compiler branch is preserved in
`archive/lafont-attempt/`; it is not part of the active path.
