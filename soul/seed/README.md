# Seed — ядро языка Saltic

`seed` — самохостящееся ядро: парсер, чекер, компилятор и машинный слой
написаны на самом Saltic. Эталон языка — `soul/canonical/`.

## Слои

Ядро делится на три слоя, каждый подключается по своему корню:

- `core/` — то, что нужно любой программе: `core.str`, `core.group`,
  `core.num`, `core.mem`, фиксированные значения `core.u8` … `core.usize`,
  `core.bits32`, `core.address`, а также `core.cpu`, `core.time`,
  `core.process`, `core.system`, `core.bytes`, `core.dict`, `core.arena`, на
  64-битных целях — `core.fraction` и `core.matrix`. Сравнение секретов —
  `craft.protocols.security.crypto` (Q-023).
- `io/` — вывод (`use io`, вход `main.saltic`), файлы (`use io.file`).
- `compiler/` — сам язык: `compiler.architect`, `compiler.parser`, `compiler.checker`,
  `compiler.gorn` и всё, на чём они стоят.

Модуль архитектор ищет по углам: `soul/seed/`, потом `soul/`, потом корень
проекта (`compiler/architect/main.saltic`).

## Язык

- ключевые слова: `use`, `skill`, `program`, `out`, `Box`, `enum`, `drum`,
  `always`, `pick`, `leave`, `rescue`, `native`;
- значения `yes`, `no`, `none` — тоже ключевые слова, всего их 15
  (`parser/lexer.saltic`, `KEYWORDS`); отрицания нет, только `== no`;
- одно имя вводится через `@`, дальнейшая запись идёт без `@`;
- ошибка — значение (`error.Имя`), не отдельный режим; `rescue` подставляет
  запасной результат.

Память программы — одна квота. Каждый вызов skill открывает регион: на выходе
результат `out` копируется вызывающему, остальная память региона
освобождается целиком. Нехватка памяти — ошибка `MemoryExhausted`, её ловит
`rescue`. Сборщика мусора нет. Подробно — `docs/language/MEMORY-MODEL.md`.

## Устройство `compiler`

- `architect/` — первая ступень: из каких файлов программа и как они связаны (`use` → файл, связи, порядок);
- `parser/` (`main`, `lexer/`, `syntax/`, `token`, `nest`) — текст файла в дерево;
- `checker` + `checker/{names,signatures,rules,types,lookup,walk,top_level}` — проверка: верх программы, обход выражений и инструкций, справки об именах;
- `errors` — каталог ошибок языка: у каждой свой навык с кодом и текстом
  (`errors.unknown_name(name)`); `diagnostic` ставит её на место в файле;
- `gorn` + `gorn/{codegen,functions,state,constants}` — перевод в
  машинный код: `codegen` — сердце (выражения, инструкции, вызовы) с
  помощниками `codegen/{lookup,emitters,loops,failures}`, `functions` собирает
  функции и константы; всё это говорит на договоре машины `gorn/backend`
  (роли регистров и операции) методами исполнителя `compiler.executor`;
  исполнители: `gorn/backend/riscv/rv32i` (`Executor`), родной x86-64
  `gorn/backend/x86/x86_64` (`Executor` на `encoder`, `roles`, `ops`,
  `access`, `control`; `platform` — вход и syscall Linux, `image` — ELF64,
  `uefi` и `pe` — UEFI) и RV64 `gorn/backend/riscv/rv64`; перевод RV32I →
  x86-64 — на пенсии (`.archive/x86_64_translation/`);
- `gorn/platform` + `platform/{linux,uefi}` — договор платформы: метки
  `rt_platform_*` (write, exit, key, file_read, file_write, now, wait, firmware,
  call), которые цель даёт программе; чего не умеет — ошибка `NotSupported`.
  Платформа — Box с методом `append(compiler)`: `platform.linux.Linux`,
  `platform.uefi.Uefi`, `soul/seed/compiler/gorn/platform/qemu_virt.Platform`;
- `gorn/backend/runtime` + `runtime/{numbers,collections,strings,fixed,raw_memory,host,memory,terminal}` —
  машинный runtime `rt_*` на договоре машины (роли и операции `gorn/backend`,
  общий для исполнителей): арифметика, Box и группы, строки,
  фиксированные типы, прямой доступ к памяти, ввод-вывод, регионы памяти и печать;
- `gorn/backend/{buffer,layout}` — байтовый буфер и программа в сборке, общие
  для всех; `gorn/backend/riscv/{main,instruction,registers,codec,emit,fixer}`
  — общее семьи RISC-V: таблица команд (`Instruction`, `Catalog`), кодирование,
  команды и переходы, правки; `riscv/rv32i/{profile,elf}` — паспорт машины и ELF32;
- `machine/word` — 32-битное слово из четырёх байтов, общее для всех
  бэкендов, образов и ОС; `machine/wide` — 64-битное из двух `word` (константы
  RV64, поля ELF64). Компилятор считает ими, потому что работает и на RV32I,
  где обычное число 29-битное; на RV64 и x86-64 оно 61-битное;
- `abi` — одно машинное слово, теги значений, номер ошибки в отдельном
  регистре, 12-байтовый заголовок объекта;
- `toolchain.saltic` — точка входа компилятора.

## Цели и сборка

Исходник собирается прямо в образ: ELF для `rv32i` (Linux и `qemu_virt`), ELF
для `x86_64` Linux и PE32+ для `x86_64-uefi`. Текст ассемблера, GNU `as`/`gcc`
и JavaScript в эту цепочку не входят.

Восстановление компилятора — готовые файлы
`bootstrap/saltic-<версия>-compiler-<проц>-<платформа>` из Git, не сборка
из исходников. Рядом с каждым лежит паспорт `.txt`: версия, хеш исходников,
чем собран и сходится ли самосборка.

Проверка ядра входит в общий прогон `just test` (`tests/run.sh`).
