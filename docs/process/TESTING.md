# Тестирование

Черновик. Принципы утверждает автор.

## Принципы

1. **Концентрат.** Тест проверяет одно поведение одной проверкой. Сто
   проверок того же самого на разных числах — это одна проверка.
2. **Без дублей.** Если поведение уже доказано другим тестом или
   `refresh.saltic`, второй тест не пишется.
3. **Баг — с тестом.** Исправление бага приходит с проверкой, которая
   падала до исправления.
4. **Канон — первый тест языка.** Новая возможность попадает в
   `soul/canonical/main.saltic`, новое правило чекера — в свой случай
   `soul/canonical/checks/errors/<тема>.saltic`; ожидаемый вывод — в `expected/`.
5. **Один вход.** Все проверки запускает `tests/run.saltic`, все идут в каждом
   прогоне `global-check`. Тест, который не запускается, удаляется.
6. **Тишина при успехе.** Прошедший тест печатает одну строку итога.
   Упавший говорит, что ожидалось и что пришло.
7. **Быстро.** Медленный тест должен оправдать своё время тем, чего не
   проверяет никто другой.

## Группы

`just test <набор>` (программа `tests/run.saltic`, собирается полкой)
запускает набор или случаи по именам через пробел; без имени — `all`. Хост
тестовых программ — `SALTIC_TEST_HOST`: `x86_64` (по умолчанию в `just test`),
`rv32i` (под `qemu-riscv32`), `rv64` (под `qemu-riscv64`); запускать из
проектного Nix shell (нужны qemu, в том числе aarch64).

`all` — её гоняет `just global-check` разом на rv32i, x86_64, rv64 и arm64:

- `checker` — случаи `soul/canonical/checks/errors/` против `expected/errors/`;
  `errors/parser/` — по файлу на ошибку лексера и парсера, каждый обязан
  упасть с `ParseFailed`;
- `fixed-types` — `u8…usize`, `bits32`, `address` и их ошибки чекера;
- `fraction`, `wide` — дробные и канон 64 бит `soul/canonical/wide/main.saltic`
  на x86-64, rv64 и arm64;
- `modules` — вложенные модули и ошибки загрузчика;
- `json-rpc` — `craft.protocols.data.json` и `json_rpc`;
- `diagnostics` — форма диагностик лексера, парсера, загрузчика и чекера;
- `groups` — группа-дерево на 40, 1 000 и 50 000 элементов;
- `bytes` — `core.bytes`: края, ошибки по имени, миллион байтов;
- `dict` — `core.dict` под rv32i и x86_64;
- `platform` — договор платформы на Linux (rv32i и x86_64): `NotSupported`
  по имени, непойманная ошибка, программа без аргументов;
- `x86-encoder` — байты команд кодировщика x86-64 (эталоны GNU `as`,
  `workbench/check/x86-encoder-golden.saltic`);
- `arm64-encoder`, `xtensa-encoder` — байты команд AArch64 и Xtensa LX6
  против эталонов GNU `as`;
- `arm64` — канон, `edges`, `always`, большие числа и большая куча, собранные
  под ARM64, под `qemu-aarch64`: тот же вывод, что у rv64;
- `crypto` — `craft.protocols.security.crypto` (сравнение секретов за
  постоянное время);
- `apk` — части APK из `formats/apk`: CRC32, zip, подпись;
- `edges` — канон граничных случаев `soul/canonical/edges/main.saltic` (из `tests/`
  12.11.2026): ошибки рантайма через `rescue`, дерево Box, строки, злые значения
  каждого типа через параметр, out, группу, поле Box, `"{x}"` и `==`; одинаково
  под rv32i и x86_64;
- `rv64` — канон, `edges`, `always` и `big-numbers`, собранные под RV64, под `qemu-riscv64`: тот
  же вывод, что у rv32i и x86_64;
- `rva23` — кодировщик RV64: каждая из 1054 команд RVA23 с базовыми и
  псевдослучайными операндами сверяется побайтно с GNU-ассемблером
  (`workbench/check/rva23/verify.py`); таблицу пишет `workbench/check/rva23/generate.py`;
  затем «форма = таблица» — команды, которые исполнитель rv64 кодирует по
  форме (`rv64/machine/forms`), сверяются с таблицей на случайных операндах;
- `process` — `core.process` (run, capture, lines, папка ребёнка, PATH, окружение)
  и `io.file.list` под rv32i, x86_64 и rv64;
- `always` — регион на оборот: 200 000 оборотов с Box в куче 1 МБ, внешние
  переменные, поля Box, `out`, ошибки и вложенный `always`; под rv32i и x86_64;
- `seed-contract` — контракт ядра (`soul/seed/tests/contract/`, вход `main.saltic`, дети-субъекты по темам);
- `machine` — машинный слой RV32I и провал набора `craft.testing`;
- `abi` — теги значений, пространство ошибок, упаковка;
- `memory` — модель памяти и `MemoryExhausted`; пытки памяти
  (`tests/memory/*`: forever, depth, width, fragment, tangle, breaks, quota,
  impostor, cycles) — отдельный набор `memory`, в `all` не входят;
- `native` — канон, память, переполнение стека, нажатия, импорт и большие
  числа на родном x86-64;
`os` — модули ОС, не язык; в `just global-check` (под x86_64):

- `jtml`, `tasks` — `registry.libraries.uiengine.jtml` и `os.apps.tasks`;
- `ttf` — шрифты TTF (`os/fonts/ttf`, `os/fonts/raster`) на Inter;
- `events` — ядро событий и жесты (`os/input/events`, `os/input/gestures`);
- `panels`, `mrpc` — системная панель и mRPC агента (`mrpc` — всегда под
  x86_64: модули ОС UEFI — 61-битный мир).

`platforms` — в `just global-check` (под rv32i):

- `qemu-virt` — ОС с графикой собирается и стартует в QEMU;
- `uefi` — образ UEFI собирается и грузится под OVMF;
- `closure` — канон родным компилятором с полки в ELF rv32i и запуск в QEMU.

`platforms` в `global-check` с 08.11.2026 — принцип 5 соблюдён. Решение
автора 03.11.2026 — папка `tests/` переезжает в канон (чек-лист
[PLAN.md](../plan/PLAN.md), «Надёжность»); этот список уйдёт вместе с ней.
