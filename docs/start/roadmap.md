# Дорожная карта

Эта дорожная карта описывает путь S от первых строк до цифровой бумаги для личной вычислительной экосистемы.

Главный принцип: каждый этап должен давать проверяемый результат. Если этап нельзя запустить, распарсить, проверить или показать на примере, он ещё не завершён.

## Текущее состояние

S уже прошёл первый важный рубеж: `.s` файл можно не только распарсить и проверить, но и выполнить внутри Racket.

После этого проект начал переход от Racket-only runtime к bytecode VM и S-side bootstrap VM.

Рабочая демонстрация:

```bash
just run
```

Она запускает:

```bash
racket tools/run.rkt examples/bootstrap/basic.s
```

Текущий вывод:

```text
ok
tick
tick
tick
tick
tick
```

Сейчас S — это маленький исполняемый прототип языка с ранним self-hosting контуром:

```text
S source
-> Racket parser/checker
-> Racket tree runtime

S source
-> Racket parser/checker/compiler
-> S bytecode
-> Racket VM
-> S-side tiny VM semantics subset
```

Текущая автономность: около `40%`.

Подробно: [Autonomy score](autonomy-score.md) и [Self-hosting roadmap](self-hosting-roadmap.md).

Долгосрочный центр проекта:

```text
paper -> check -> explain -> run -> observe -> modify -> persist
```

S нужен не только для написания программ. S нужен как единая запись для данных, действий, агентов, роботов, программ, движков, игр, студий, миров, runtime и собственного железа.

Главные vision-документы:

- [Digital paper](../vision/digital-paper.md)
- [Ideal system](../vision/ideal-system.md)
- [Runtime freeze](runtime-freeze.md)
- [Self-hosting roadmap](self-hosting-roadmap.md)

## Статусы

```text
[done]    Этап 0. Черновик языка
[done]    Этап 1. Минимальная грамматика
[done]    Этап 2. Parser на Racket
[done]    Этап 3. Checker
[done]    Этап 4. Интерпретатор первого подмножества
[done]    Этап 5. Foundation перед world MVP
[done]    Этап 6. Удобство письма: formatter, diagnostics, examples
[done]    Этап 7. Runtime и первые core modules
[done]    Этап 8. World/visual protocol slices
[active]  Этап 9. Bytecode VM
[active]  Этап 10. S-side tiny VM bootstrap
[next]    Этап 11. Boundary table expansion
[future]  Этап 12. Offline cookbook
[future]  Этап 13. IR
[future]  Этап 14. S toolchain wrapper
[future]  Этап 15. Parser/checker/compiler fragments on S
[future]  Этап 16. Self-hosting chain
[future]  Этап 17. Backend под собственную архитектуру
```

## Этап 0. Черновик языка

Цель: зафиксировать направление.

Готово, когда:

- есть README;
- есть философия языка;
- есть базовый пример `examples/bootstrap/basic.s`;
- есть документы по синтаксису, типам, ошибкам, runtime и Racket bootstrap;
- понятно, что S является автономным и агентным системным языком.

Текущий статус: готово для `v0.1` направления.

## Этап 1. Минимальная грамматика

Цель: описать первое подмножество S, которое можно парсить.

Минимальный состав:

- константы;
- переменные;
- числовые и строковые литералы;
- вызовы функций;
- `skill`;
- `out`;
- блоки `{ ... }`;
- условия `(expr) { ... }`;
- `drum (N) { ... }`;
- `rescue`;
- `enum`.

Результат:

```text
docs/current/grammar.md
```

Готово, когда:

- `examples/bootstrap/basic.s` покрывается грамматикой;
- для каждой конструкции есть короткий пример;
- спорные места вынесены в открытые вопросы.

## Этап 2. Parser на Racket

Цель: получить AST из `.s` файла.

Команда:

```bash
racket tools/parse.rkt examples/bootstrap/basic.s
```

Результат:

```text
.s source -> AST
```

Готово, когда:

- `examples/bootstrap/basic.s` парсится без ошибок;
- AST выводится в читаемом виде;
- parser показывает строку и место ошибки;
- есть несколько негативных примеров, которые должны падать.

Текущий статус: готово для первого подмножества.

## Этап 3. Checker

Цель: начать проверять смысл программы.

Минимальные проверки:

- объявление переменных;
- первое присваивание фиксирует тип;
- повторное присваивание совместимо с типом;
- константы нельзя изменять;
- `out` используется внутри `skill`;
- имена функций существуют;
- enum-значения существуют;
- базовая проверка scope.

Команда:

```bash
racket tools/check.rkt examples/bootstrap/basic.s
```

Готово, когда:

- корректный `basic.s` проходит проверку;
- типичные ошибки дают понятные diagnostics;
- checker не пытается быть полным компилятором.

Текущий статус: готово для первого подмножества.

## Этап 4. Интерпретатор первого подмножества

Цель: запустить маленькую программу на S внутри Racket.

Команда:

```bash
racket tools/run.rkt examples/bootstrap/basic.s
```

Или:

```bash
just run
```

Минимальный runtime:

- значения;
- переменные;
- функции;
- `out`;
- условия;
- `switch`;
- `drum (N)`;
- вызовы;
- `host.io.println`;
- простая модель ошибок и `rescue`.

Готово, когда:

- `examples/bootstrap/basic.s` исполняется;
- есть тесты runtime;
- ошибки исполнения понятны;
- поведение детерминировано.

Текущий статус: первый вертикальный срез готов.

## Этап 5. Foundation перед world MVP

Цель: зафиксировать фундамент, на котором будет строиться физическая эмуляция мира.

Результат:

```text
docs/start/foundation.md
```

Минимальный состав:

- program model;
- value model;
- error model;
- namespace model;
- interop model;
- library model;
- action model;
- trace model;
- world MVP preconditions.

Готово, когда:

- понятно, что такое world object handle/ref;
- понятно, что такое action;
- понятно, что такое trace;
- ясно отделены `core.engine`, `world.*`, `tool.*`, `agent.*`;
- world MVP можно делать маленьким вертикальным срезом, а не обычным приложением.

## Этап 6. Удобство письма

Цель: сделать один официальный стиль S.

Команда:

```bash
racket tools/format.rkt examples/bootstrap/basic.s
```

Готово, когда:

- formatter стабильно форматирует `basic.s`;
- повторный запуск не меняет файл;
- стиль уменьшает выбор для человека и агента;
- спорные стилистические решения зафиксированы в docs.

Дополнительно на этом этапе:

- diagnostics со строками и колонками;
- больше маленьких примеров в `examples/`;
- единый стиль для документации и примеров;
- команда `just run-file <file>` как основной способ пробовать свои программы.

## Этап 7. Runtime и будущая core.informatics.base

Цель: сделать S полезным для нескольких простых задач, а не только для `basic.s`.

Минимум bootstrap runtime:

- `host.io`;
- `host.file`;
- `host.str`;
- `host.math`;
- `host.time`;
- простой CLI ввод;
- тестирование S-программ;
- понятные runtime errors.

Готово, когда:

- можно написать несколько маленьких инструментов;
- ясно отделены `host.*` intrinsics, `sys.*` и будущая `core.informatics.base`;
- API остаётся коротким и запоминаемым;
- runtime покрыт тестами.

## Этап 8. World MVP

Цель: впервые получить изменяемый физический world state и воспроизводимый trace действий.

Минимум:

- объект мира;
- позиция или простое состояние;
- action log;
- simulate step;
- trace output;
- replay trace.

Готово, когда:

- S-сценарий создаёт объект;
- действие меняет world state;
- trace можно сохранить или вывести;
- replay даёт тот же state;
- графика не обязательна.

## Этап 9. Bytecode VM

Цель: отделить runtime semantics от tree-walking Racket runtime.

Текущий результат:

```text
S source -> Racket parser/checker/compiler -> S bytecode -> Racket VM
```

Готово сейчас:

- bytecode dump;
- VM execution for core examples;
- numbers, strings, variables, calls, arithmetic, `out`;
- `Box`, field access, `Group`;
- `if`, `drum`, `switch`, `rescue`;
- visual/world protocol slices;
- object skill calls.

Остаётся:

- запускать больше canonical/user examples через VM;
- держать bytecode v0 contract ближе к implementation;
- не превращать Racket VM в единственный источник смысла.

## Этап 10. S-side tiny VM bootstrap

Цель: начать переносить смысл VM instructions в S-код.

Текущий результат:

```text
examples/bootstrap/tiny_vm/core.s
```

Покрыто:

- Group A: stack/load/store/pop;
- Group B: arithmetic and compare;
- Group C: `group`, `box-new`, `field`;
- Group D: `if`, `drum`, `switch`, `rescue`, `return`;
- Group E: local calls and first boundary table for `core.io.println`.

Готово, когда:

- tiny VM examples проходят и через tree runtime, и через bytecode VM;
- `step_tiny` остаётся маленькой переносимой моделью;
- новые semantics добавляются в S model, а не только в Racket `step!`.

## Этап 11. Boundary table expansion

Цель: сделать host/protocol calls явной моделью, а не набором special cases.

Текущий next action:

```text
Extend S VM Step Group E boundary table
```

Кандидаты:

- `core.group.count`;
- `core.group.at`;
- `core.str.add`;
- `visual.trace_text`;
- `world.trace_text`.

Готово, когда:

- выбран следующий boundary handler;
- он представлен в S-side `BoundaryTable`;
- есть runnable example;
- есть runtime/vm tests;
- docs updated.

## Этап 12. Offline cookbook

Цель: сделать S пригодным для разработки без интернета.

Результат:

```text
docs/cookbook/
```

Минимальные рецепты:

- вывести строку;
- прочитать файл;
- записать файл;
- пройти по группе;
- сделать CLI;
- обработать ошибку;
- написать state machine;
- написать agent loop.

Готово, когда:

- каждый рецепт запускается или хотя бы парсится;
- каждый рецепт короткий;
- рецепты отвечают на реальные задачи, а не демонстрируют синтаксис ради синтаксиса.

## Этап 13. IR

Цель: отделить модель программы от конкретного bootstrap backend.

Bytecode VM сейчас является практическим ранним контрактом исполнения:

```text
S AST -> S bytecode -> VM
```

Но отдельный IR всё ещё нужен как более общий слой для анализа, оптимизации, compiler passes и будущих backend-ов:

```text
S AST -> checked AST -> IR -> bytecode/native/hardware backend
```

IR должен быть:

- маленьким;
- явным;
- backend-neutral;
- удобным для анализа агентами;
- независимым от синтаксического сахара;
- совместимым с текущим bytecode v0, но не обязанным быть тем же самым форматом.

Готово, когда:

- `basic.s` и несколько canonical examples проходят путь до IR;
- IR можно вывести в текстовом виде;
- понятно, как в IR представлены функции, блоки, условия, циклы, ошибки и effects;
- описано отношение `IR -> bytecode v0`.

## Этап 14. S toolchain wrapper

Цель: собрать отдельную CLI-утилиту вокруг языка.

Возможные команды:

```text
s parse
s format
s check
s run
s test
s docs
s example
s explain
```

Готово, когда:

- Racket-скрипты скрыты за единой командой;
- toolchain помогает писать без интернета;
- diagnostics становятся частью UX языка.

## Этап 15. Parser/checker/compiler fragments on S

Цель: начать переносить части tooling с Racket на S без остановки разработки.

Порядок переноса:

1. diagnostics helpers;
2. bytecode/debug helpers;
3. parser helpers;
4. checker fragments;
5. compiler fragments;
6. больше runtime/tooling.

Готово, когда:

- часть toolchain написана на S;
- Racket всё ещё может оставаться host-средой;
- перенос не ломает скорость разработки.

## Этап 16. Self-hosting chain

Цель: S способен собирать существенную часть себя.

Самохостинг не обязан быть абсолютным с первого дня.

Уровни:

- **partial self-hosting:** formatter/checker/helpers на S;
- **toolchain self-hosting:** основной toolchain на S;
- **compiler self-hosting:** S компилирует компилятор S;
- **platform self-hosting:** S может быть основным языком runtime/firmware/tooling.

Готово, когда:

- новый toolchain можно собрать предыдущей стабильной версией S;
- bootstrap chain документирована;
- есть rollback path.

## Этап 17. Backend под собственную архитектуру

Цель: S становится системным языком для своей ISA.

До появления архитектуры этот этап не блокирует разработку языка.

Подготовить заранее:

- IR;
- memory model;
- calling convention draft;
- error model;
- runtime boundaries;
- core/kernel split;
- embedded profile.

Готово, когда:

- S-программа собирается под свою ISA;
- есть минимальный runtime;
- есть hello-world или firmware-level пример;
- behavior совпадает с моделью языка.

## Главная линия

```text
examples/bootstrap/basic.s
  -> grammar
  -> parser
  -> checker
  -> interpreter
  -> formatter + diagnostics
  -> runtime + core.informatics.base
  -> world/visual slices
  -> bytecode VM
  -> S-side tiny VM
  -> boundary table
  -> cookbook
  -> IR
  -> S toolchain
  -> parser/checker/compiler fragments on S
  -> self-hosting
  -> own ISA backend
```

## Правило движения

Не переходить к следующему большому этапу, пока предыдущий нельзя показать маленькой командой.

Лучший ближайший milestone:

```bash
just s-vm-step-boundary-vm
```

Следующий лучший milestone:

```bash
just verify
```
