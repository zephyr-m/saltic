# RV32I — бэкенд

✅ **Есть.** Здесь только своё у RV32I; общее семьи RISC-V — в `../`
(таблица команд, регистры, кодек, ассемблер, `emit`, `fixer`), общее всех
бэкендов — в `../../` (`layout`, `image`, `buffer`, `runtime`). Вход —
`main.saltic`: исполнитель договора машины `Executor` (Box с методами
`../../main.saltic`, роль → регистр по `REGISTER_OF_ROLE`).

| Что | Где | Строк |
|---|---|---|
| Вход: исполнитель договора `Executor`; фасад команд, меток, переходов, ELF | `main.saltic` | ~340 |
| Паспорт машины | `profile` | ~70 |
| ELF32 RISC-V: заголовки, символы, `executable`, `write` | `elf` | ~250 |

Переехало сюда 03.11.2026 из `compiler/machine/` и
`compiler/gorn/runtime/emit*` (шаг 1 отвязки компилятора от
архитектуры). Осталось на месте общее: `compiler/machine/word` — 32-битное
слово, нужное и переводу в x86-64, и образам, и ОС.

**Договор машины (шаг 2, 03.11.2026).** `codegen`, `functions` и `state`
больше не называют регистры и команды RV32I: они говорят «положи число 5»,
«вызови навык», «перейди, если ноль» — методами `compiler.executor`
(`../../main.saltic`). `Executor` отсюда переводит роли в регистры и зовёт
`assembler.emit_op` / `machine.layout`. Машинный код программ от этого не
изменился ни на байт (`.archive/docs/fable/2026-11-03-contract.md`).

**Рантайм на договоре (шаг 3, 04.11.2026).** `runtime/*` тоже говорит
только ролями и операциями договора (`executor.load`, `executor.syscall`,
`executor.branch_less_unsigned`…) — ни одного `instruction.Kind`,
`registers.*` или `assembler.emit_op` в нём не осталось. Договор для этого
дорос до 21 роли (последняя — `SCRATCH5`). Скрытые
договорённости между `rt_*` названы: `memory.BARRIER_OBJECT` (адрес Box на
входе в `rt_region_barrier`), `memory.RELOCATION_DELTA` (сдвиг при переносе
региона), `numbers.EQUAL_YES / EQUAL_NO` (метки ответов, в них
прыгает `fixed`); провалы меток (`rt_string_upper → rt_string_case`,
`rt_fixed_mem_load32 → load`, `store32 → store`) — внутри одного навыка.
Машинный код не изменился, кроме двадцати пересылок `add rd, rs, x0 →
addi rd, rs, 0` (`.archive/docs/fable/2026-11-03-runtime.md`). С 22.11.2026 рантайм
и буфер байтов — общие: `backend/runtime/` и `backend/buffer` (решение автора). Thumb-2, Xtensa и ARM64 получают codegen и рантайм бесплатно,
им нужны только исполнитель, образ и платформа.

`layout` (теперь `backend/layout`) берут и другие исполнители
(родной x86-64, RV64). Перевод RV32I → x86-64 — на пенсии с 06.11.2026
(`.archive/x86_64_translation/`).

RV32I останется бэкендом и после того, как перестанет быть центром
(машина-максимум, эпоха 5): RP2350 на ядрах Hazard3, дальше — RV64.
