# Seed — ядро языка Saltic

Ядро закрыто для обычной разработки. Новая возможность, второй способ сделать то же самое и новая публичная граница сюда не добавляются. Меняется только ошибка в уже записанном контракте.

`seed` — самохостящееся ядро: парсер, чекер, компилятор, виртуальная машина и
машинный слой (кодировщик, раскладка, ELF-образ) написаны на самом Saltic.

## Публичные границы

Программа на Saltic видит один язык и модули `seed`. Второй способ выразить ту же вещь не добавляется.

Язык:

- `use`, `skill`, `program`, `out`, `Box`, `enum`, `drum`, `rescue`, `@`
- значения `yes`, `no`, `none`
- ошибка — значение, не отдельный режим; `rescue` подставляет запасной результат
- одно имя вводится через `@`, дальнейшая запись идёт без `@`

Модули программы:

- `seed.io` — вывод
- `seed.file` — чтение и запись файлов
- `seed.group`, `seed.str`, `seed.num` — группы, строки, числа
- `seed.process` — завершение процесса

Память программы одна. Курсор кучи едет только вперёд. Место кончилось — процесс завершается с кодом 65. Сборщика мусора нет.

Сборка канона одна: исходник → прямой ELF. Текст ассемблера, GNU `as`/`gcc` и JavaScript в эту цепочку не входят. Восстановление компилятора — файл `os/bootstrap/compiler.elf` из Git, не сборка из `.s`.

Внутреннее ядро не является вторым языком для программ:

- `parser`, `checker`, `compiler`, `runtime/emit.saltic` — перевод в машинный ELF
- `machine` — команды, раскладка, образ ELF
- `vm` — исполнение ELF внутри Saltic
- `abi` — одно машинное слово и номер ошибки в отдельном регистре

Фиксированная точка текущего ядра, stage-2 и stage-3: `c4a5152efd028328273385b55553e66c379e1f84d0ffa4aa2689ebe8d4513cba`.

## Реальное состояние vs. план

На карте `vision.mmd` часть сущностей отмечена **планируемыми**, а не
существующими. Ниже — фактическое состояние на текущий момент.

### Готово и проверяется `just test`

- **парсер** — `parser.saltic` + `parser/{lexer,loader,syntax}`;
- **чекер** — `checker.saltic` + `checker/{names,signatures,rules,types,semantics}`;
- **компилятор** — `compiler.saltic` + `compiler/{codegen,state,constants}`,
  backend `compiler/backend/rv32i`;
- **runtime** — `runtime/emit.saltic` (машинный runtime);
- **машина (пункт 5 аудита)** — `machine/{instruction,codec,layout,image,profile}`:
  собственное кодирование 44 команд, раскладка, ELF32-образ. Закрыто
  независимыми тестами (golden/immediate/patches/elf/scale).
- **VM** — `vm.saltic` + `vm/{cpu,loader,state,syscalls,system}`.

### Планируется (пункты 6–8 аудита, файлов ещё нет)

- `compiler/abi.saltic` — новый call/value ABI (сейчас ABI описан контрактом,
  но активный compiler/runtime ему не соответствуют);
- `runtime/{start,value,group,string,platform}.saltic` — перевод runtime с
  assembly-строки на `machine.Program`;
- `platform/contract.saltic`, `os/bootstrap/platform.saltic` — явная граница платформы;
- `vm/word.saltic` — общее машинное слово для codec и VM;
- `tests/closure.saltic` — доказательство замкнутости.

## Известное расхождение (до пункта 6)

Контракты ABI и модель памяти существуют в **двух несовместимых версиях**:

- **новый контракт** (`abi/*`, `memory/model.saltic`) описывает raw fixed в
  32-битном слове, отдельный error в `a1`, 16-байтовый object header,
  конечную память с освобождением;
- **активный runtime** (`runtime/emit.saltic`,
  `compiler/constants.saltic`) по-прежнему выделяет fixed в куче с `TAG_BOX`,
  возвращает ошибку в `a0`, не имеет 16-байтовых headers и bump-only heap
  без сборки.

Эти расхождения устраняются только в пункте 6 аудита (перевод compiler/runtime
на `machine.Program` + mark-and-sweep). До этого два контракта сосуществуют
сознательно: старый — рабочий, новый — спецификация перехода.
