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
| Рантайм `rt_*` на ассемблере RV32I | `runtime.saltic` + `runtime/{numbers,collections,strings,fixed,raw_memory,memory,terminal,host}` | ~2 850 |

Переехало сюда 03.11.2026 из `selfhost/machine/` и
`selfhost/compiler/runtime/emit*` (шаг 1 отвязки компилятора от
архитектуры). Осталось на месте общее: `selfhost/machine/word` — 32-битное
слово, нужное и переводу в x86-64, и образам, и ОС.

**Договор машины (шаг 2, 03.11.2026).** `codegen`, `functions` и `state`
больше не называют регистры и команды RV32I: они говорят «положи число 5»,
«вызови навык», «перейди, если ноль» — методами `compiler.executor`
(`../backend.saltic`). `Executor` отсюда переводит роли в регистры и зовёт
`assembler.emit_op` / `machine.layout`. Машинный код программ от этого не
изменился ни на байт (`docs/fable/2026-11-03-contract.md`).

Рантайм `runtime/*` пока на ассемблере с номерами регистров через
`assembler.emit_op` — шаг 3 (на договоре или на самом Saltic) решает
автор. Без него Thumb-2, Xtensa и ARM64 получат codegen бесплатно, а
рантайм — нет.

Перевод в x86-64 (`../x86_64_translation/`) берёт готовую машину RV32I и
потому зависит от `machine/{layout,image,instruction,decoder,profile,buffer}`
отсюда.

RV32I останется бэкендом и после того, как перестанет быть центром
(машина-максимум, эпоха 5): RP2350 на ядрах Hazard3, дальше — RV64.
