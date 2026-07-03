# Текущий рабочий план

Этот файл фиксирует ближайшую реальную линию работы, а не исторический план первого вертикального среза.

## Текущее состояние

S уже вышел за пределы первого `parse -> check -> run` прототипа.

Сейчас есть:

- parser/checker/runtime на Racket;
- formatter, diagnostics, `explain`;
- runnable user examples и task pack;
- `core` modules на S для части строк, чисел, файлов и JSON;
- bytecode VM на Racket;
- bytecode v0 contract;
- S Machine / VM Step v0 docs;
- S-side tiny VM bootstrap interpreter;
- VM Step Group A/B/C/D в tiny VM;
- Group E local calls и первый S-side boundary dispatch table для `core.io.println`;
- std autonomy pass 1: `core.str.at/slice` and S-side string algorithms `contains/lines_count/is_empty/starts_with/ends_with`;
- world/visual protocol slices;
- object skill call model and runnable VM example.

Практическая оценка автономности:

```text
S autonomy: about 40%
Racket dependency: about 60%
```

Подробная шкала: [Autonomy score](autonomy-score.md).

## Выполнено из старого плана

Старый план был про удобство первого вертикального среза.

Готово:

- `just explain <file>`;
- diagnostics с `line:col` для важных checker errors;
- `examples/user/finance-log.s`;
- task runner и первые задачи;
- formatter/runtime/checker/parser tests;
- world event protocol through `world.emit` + `world.step`;
- syntax decision: текущая конструкция называется `switch`.

Старые пункты `World MVP 2` и `Examples pack` не удалены как направление, но они больше не являются главным next action.

## Current next action

```text
Extend S VM Step Group E boundary table
```

Почему это следующий шаг:

- Group A/B/C/D уже перенесены в tiny VM bootstrap form;
- local calls уже отделены от boundary calls через `CallKind`;
- `core.io.println` уже проходит через S-side `BoundaryTable`;
- остальные `core.*`, `host.*`, `visual.*`, `world.*` boundary effects всё ещё в основном живут в Racket;
- без явной boundary table следующий перенос снова превратится в список special cases внутри `step_tiny`.

Готово, когда:

- выбран следующий boundary handler;
- handler представлен в S-side boundary table/model;
- есть runnable example через tree runtime и bytecode VM;
- есть runtime/vm test coverage;
- docs обновлены в [VM Step v0](../spec/vm-step-v0.md) и [Self-hosting roadmap](self-hosting-roadmap.md).

## Candidate next handlers

Кандидаты:

```text
core.group.count
core.group.at
core.str.lines
core.str.split
world.trace_text
visual.trace_text
```

Наиболее прагматичный следующий шаг:

```text
core.group.count / core.group.at
```

Причина: они уже широко используются в examples/tasks и помогут tiny VM выполнять больше S-side программ без расширения world/visual протоколов.

## Команды проверки

Минимум для текущей линии:

```bash
just s-vm-step-boundary
just s-vm-step-boundary-vm
env TMPDIR=/tmp raco test tests/runtime.rkt tests/vm.rkt
```

Полный локальный контракт:

```bash
just verify
```
