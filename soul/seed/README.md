# Seed — ядро языка Saltic

`seed` — самохостящееся ядро: парсер, чекер, компилятор, виртуальная машина и
машинный слой (кодировщик, раскладка, ELF-образ) написаны на самом Saltic.

## Реальное состояние vs. план

На карте `vision.mmd` часть сущностей отмечена **планируемыми**, а не
существующими. Ниже — фактическое состояние на текущий момент.

### Готово и проверяется `just test`

- **парсер** — `parser.saltic` + `parser/{lexer,loader,syntax}`;
- **чекер** — `checker.saltic` + `checker/{names,signatures,rules,types,semantics}`;
- **компилятор** — `compiler.saltic` + `compiler/{codegen,state,constants}`,
  backend `compiler/backend/rv32i`;
- **runtime** — `runtime/runtime.saltic` + `runtime/memory.saltic` (текст GNU assembly);
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
- **активный runtime** (assembly-строка в `runtime/runtime.saltic`,
  `compiler/constants.saltic`) по-прежнему выделяет fixed в куче с `TAG_BOX`,
  возвращает ошибку в `a0`, не имеет 16-байтовых headers и bump-only heap
  без сборки.

Эти расхождения устраняются только в пункте 6 аудита (перевод compiler/runtime
на `machine.Program` + mark-and-sweep). До этого два контракта сосуществуют
сознательно: старый — рабочий, новый — спецификация перехода.
