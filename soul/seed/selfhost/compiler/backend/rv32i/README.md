# RV32I — бэкенд

✅ **Есть.** Здесь живёт всё, что в компиляторе знает про RV32I. Вход —
`../rv32i.saltic`: исполнитель договора машины `Executor` (Box с методами
`../backend.saltic`, роль → регистр по `REGISTER_OF_ROLE`) и фасад над
`machine/layout` и `machine/image` для платформ и тестов, так же, как
`x86_64_translation.saltic` рядом со своей папкой.

| Что | Где | Строк |
|---|---|---|
| Вход: исполнитель договора `Executor`; фасад команд, меток, переходов, ELF | `../rv32i.saltic` | ~340 |
| Команды по номерам регистров: `emit_op` с широкими смещениями через T6, `load_immediate` | `assembler` | ~50 |
| Таблица команд, регистры, кодировщик и разборщик, паспорт машины | `machine/{instruction,registers,codec,decoder,profile}` | ~600 |
| Программа в сборке: секции, метки, отложенные правки | `machine/layout` | ~590 |
| ELF32 RISC-V | `machine/image` | ~300 |
| Байтовый буфер машинного кода | `machine/buffer` | ~140 |
| Рантайм `rt_*` на договоре машины (общий для исполнителей) | `runtime.saltic` + `runtime/{numbers,collections,strings,fixed,raw_memory,memory,terminal,host}` | ~2 900 |

Переехало сюда 03.11.2026 из `selfhost/machine/` и
`selfhost/compiler/runtime/emit*` (шаг 1 отвязки компилятора от
архитектуры). Осталось на месте общее: `selfhost/machine/word` — 32-битное
слово, нужное и переводу в x86-64, и образам, и ОС.

**Договор машины (шаг 2, 03.11.2026).** `codegen`, `functions` и `state`
больше не называют регистры и команды RV32I: они говорят «положи число 5»,
«вызови навык», «перейди, если ноль» — методами `compiler.executor`
(`../backend.saltic`). `Executor` отсюда переводит роли в регистры и зовёт
`assembler.emit_op` / `machine.layout`. Машинный код программ от этого не
изменился ни на байт (`.archive/docs/fable/2026-11-03-contract.md`).

**Рантайм на договоре (шаг 3, 04.11.2026).** `runtime/*` тоже говорит
только ролями и операциями договора (`executor.load`, `executor.syscall`,
`executor.branch_less_unsigned`…) — ни одного `instruction.Kind`,
`registers.*` или `assembler.emit_op` в нём не осталось. Договор для этого
дорос до 67 операций и 23 ролей (`SCRATCH5`, `SCRATCH6`). Скрытые
договорённости между `rt_*` названы: `memory.BARRIER_OBJECT` (адрес Box на
входе в `rt_region_barrier`), `memory.RELOCATION_DELTA` (сдвиг при переносе
региона), `numbers.EQUAL_YES / EQUAL_NO / LESS_YES` (метки ответов, в них
прыгает `fixed`); провалы меток (`rt_string_upper → rt_string_case`,
`rt_fixed_mem_load32 → load`, `store32 → store`) — внутри одного навыка.
Машинный код не изменился, кроме двадцати пересылок `add rd, rs, x0 →
addi rd, rs, 0` (`.archive/docs/fable/2026-11-03-runtime.md`). Рантайм лежит здесь,
потому что исполнитель RV32I — единственный; с появлением второго его место
решит автор. Thumb-2, Xtensa и ARM64 получают codegen и рантайм бесплатно,
им нужны только исполнитель, образ и платформа.

Перевод в x86-64 (`../x86_64_translation/`) берёт готовую машину RV32I и
потому зависит от `machine/{layout,image,instruction,decoder,profile,buffer}`
отсюда.

RV32I останется бэкендом и после того, как перестанет быть центром
(машина-максимум, эпоха 5): RP2350 на ядрах Hazard3, дальше — RV64.
