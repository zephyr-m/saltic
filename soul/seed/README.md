# Seed — ядро языка Saltic

`seed` — семя: всё, что нужно языку, чтобы собрать самого себя. Парсер,
чекер, компилятор и машинный слой написаны на самом Saltic. Эталон языка —
`soul/canonical/`; сборщики целей (что под что собирать) — вне семени, в
`soul/toolchains/`; инструменты языка — `soul/craft/`.

## Слои

Каждый слой подключается по своему корню:

- `core/` — то, что нужно любой программе: `core.str`, `core.group`,
  `core.num`, `core.mem`, фиксированные `core.u8` … `core.usize`, `core.i32`,
  `core.bits32`, `core.address`, `core.cpu`, `core.time`, `core.process`,
  `core.system`, `core.socket`, `core.bytes`, `core.dict`, `core.arena`; на
  64-битных целях — `core.fraction` и `core.matrix`.
- `io/` — вывод (`use io`), файлы (`use io.file`), часы (`io.clock`).
- `proof/` — проверки ядра: машина, контракт, дробные, фиксированные типы.
- `compiler/` — сам язык; своего входа у него нет, это библиотека. Вход
  компилятора с полки — `soul/toolchains/saltic`.

Модуль архитектор ищет по углам: `soul/seed/`, потом `soul/`, потом корень
проекта.

## Язык

- 15 ключевых слов: `use`, `skill`, `program`, `out`, `Box`, `enum`, `drum`,
  `always`, `pick`, `leave`, `rescue`, `native` и значения `yes`, `no`, `none`
  (`parser/lexer`, `KEYWORDS`); отрицания нет, только `== no`;
- новое имя вводится через `@`, дальнейшая запись идёт без `@`;
- навык всегда чей-то: метод своего Box; свободными остаются только
  конструкторы (своего `self` в языке пока нет);
- ошибка — значение (`error.Имя`), не отдельный режим; `rescue` ловит её на
  месте.

Память программы — одна квота. Каждый вызов навыка открывает регион: на
выходе результат `out` копируется вызывающему, остальное освобождается
целиком. Циклы ссылок запрещены. Нехватка памяти — ошибка `MemoryExhausted`.
Сборщика мусора нет. Подробно — `docs/language/MEMORY-MODEL.md`.

## Устройство `compiler`

```
compiler/
├─ architect/   из каких файлов программа: use → файл, углы поиска, советы-законы
├─ parser/      текст → дерево: lexer/, syntax/, token, nest
├─ checker/     проверка: names/, passes/, rules/, types/, walk/, notes
├─ nodes/       Nodes — чтение узлов дерева без знания обёрток
├─ report/      Diagnostic и тексты ошибок по этапам: writing, declarations,
│               naming, meaning, laws, building
├─ contract/    договор о значениях языка: abi/ (теги, объекты, вызов, ошибки),
│               intrinsic/ (встроенные навыки)
└─ gorn/        горн — дерево в машинный код
   ├─ main          Gorn — compile_machine…
   ├─ state/        State и его части: symbols, function, stub, locals,
   │                startup (_start и данные), labels
   ├─ functions, constants, codegen/   навыки, константы, выражения, вызовы, циклы
   ├─ backend/      договор машины (роли регистров и операции) и исполнители:
   │                riscv/{rv32i,rv64}, x86/x86_64, arm/arm64, xtensa/lx6,
   │                wasm/wasm32; общее — buffer, layout, runtime (rt_*)
   ├─ platform/     договор платформы Platform (rt_platform_*) и платформы:
   │                linux, uefi, qemu_virt, android, esp32, wasm
   ├─ linker/       файлы: elf64 (Elf64, Segment), shared (.so для Android)
   ├─ machine/      Word (32 бита четырьмя байтами), Wide (64 бита)
   └─ memory/       модель кучи: Allocation, Budget
```

Горн ничего не выбирает сам: исполнителя и платформу ему дают Box'ами
(`forge.compile_machine(tree, heap, executor, platform)`), выбор делает
сборщик цели.

## Цели и сборка

Исходник собирается прямо в образ, без ассемблера, GNU `as`/`gcc` и
JavaScript: ELF для Linux на rv32i, rv64, x86-64 и arm64, PE32+ для
x86-64-uefi, голый ELF для qemu-virt, образ ESP32, `.so` в APK для Android,
модуль wasm. Какой сборщик что собирает — `soul/toolchains/<цель>/`.

Восстановление компилятора — готовые файлы
`bootstrap/saltic-<версия>-compiler-<проц>-<платформа>` из Git, не сборка
из исходников. Рядом с каждым — паспорт `.txt`: версия, хеш исходников,
чем собран и сходится ли самосборка.

Проверки ядра входят в `just test` (`tests/run/main.saltic`); все входы
проекта без сборки — `just entries`.
