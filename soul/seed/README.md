# Seed — ядро языка Saltic

`seed` — самохостящееся ядро: парсер, чекер, компилятор, виртуальная машина и
машинный слой написаны на самом Saltic. Эталон языка — `soul/canonical/`.

## Слои

Ядро делится на три слоя, каждый подключается по своему корню:

- `core/` — то, что нужно любой программе: `core.str`, `core.group`,
  `core.num`, `core.mem`, фиксированные значения `core.u8` … `core.usize`,
  `core.bits32`, `core.address`, а также `core.cpu`, `core.time`,
  `core.process`, `core.system`, `core.bytes`, `core.crypto`,
  `core.graphics`. Заготовки без содержимого: `sync`, `resource`, `robot`.
- `io.saltic` и `io/` — вывод (`use io`), файлы (`use io.file`), сеть
  (`io.net`).
- `selfhost/` — сам язык: `selfhost.parser`, `selfhost.checker`,
  `selfhost.compiler` и всё, на чём они стоят.

Корни `core`, `io` и `selfhost` загрузчик ищет в `soul/seed`, корень
`canonical` — в `soul` (`selfhost/parser/loader.saltic`).

## Язык

- ключевые слова: `use`, `skill`, `program`, `out`, `Box`, `enum`, `drum`,
  `pick`, `leave`, `rescue`, `native`;
- значения `yes`, `no`, `none`; отрицания нет, только `== no`;
- одно имя вводится через `@`, дальнейшая запись идёт без `@`;
- ошибка — значение (`error.Имя`), не отдельный режим; `rescue` подставляет
  запасной результат.

Память программы — одна квота. Каждый вызов skill открывает регион: на выходе
результат `out` копируется вызывающему, остальная память региона
освобождается целиком. Нехватка памяти — ошибка `MemoryExhausted`, её ловит
`rescue`. Сборщика мусора нет. Подробно — `docs/MEMORY-MODEL.md`.

## Устройство `selfhost`

- `parser` + `parser/{lexer,loader,syntax}` — текст в дерево, загрузка модулей;
- `checker` + `checker/{names,signatures,rules,types,lookup,walk,top_level}` — проверка: верх программы, обход выражений и инструкций, справки об именах;
- `errors` — каталог ошибок языка: у каждой свой навык с кодом и текстом
  (`errors.unknown_name(name)`); `diagnostic` ставит её на место в файле;
- `compiler` + `compiler/{codegen,functions,state,constants}` — перевод в
  машинный код: `codegen` — сердце (выражения, инструкции, вызовы) с
  помощниками `codegen/{lookup,emitters,loops}`, `functions` собирает функции
  и константы; backend `compiler/backend/rv32i` и `compiler/backend/x86_64`
  (`encoder`, `translator`, `image`, `platform`, `pe`, `uefi`);
- `compiler/runtime/emit` + `emit/{numbers,collections,strings,fixed,raw_memory,host,memory,terminal}` —
  машинный runtime: арифметика, Box и группы, строки, фиксированные типы,
  прямой доступ к памяти, ввод-вывод, регионы памяти и печать;
- `machine/{instruction,registers,codec,decoder,word,buffer,layout,image,profile}` —
  команды и регистры RV32I, кодирование и разбор команд, 32-битное слово,
  байтовый буфер, раскладка, ELF32-образ;
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
