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

`logos.sv` — первая физическая клетка Candy. У неё есть собственный счётчик, inbox, outbox и локальные правила реакции на `up`, `down` и `zero`. В тесте две Logos складывают `3 + 2` передачей импульсов без центрального счётчика команд.

```bash
verilator --binary --timing --top logos_test hard/logos.sv hard/logos_test.sv
./obj_dir/Vlogos_test
```
