# Effects Inventory v0

Этот документ фиксирует текущий список runtime effects и protocol calls.

Статус: contract inventory.

## Зачем

Runtime находится в soft freeze.

Чтобы не раздувать его случайными intrinsics, все текущие эффекты должны быть видимы как явный список.

Команда:

```bash
just effects
```

Печатает текущий реестр.

## Группы

```text
host.*    bootstrap-only
std.*     user-facing standard library
world.*   world protocol
visual.*  observation protocol
```

## Kind

В inventory есть два вида:

```text
effect  меняет внешний trace/output/backend state
pure    возвращает значение без внешнего trace/output
```

Это v0-разделение.

Например, `std.str.len` является pure, а `visual.sheet` является effect, потому что пишет visual trace.

## Owner

Owner показывает слой, который отвечает за смысл:

```text
bootstrap
std
world
visual
```

Owner не всегда равен текущей реализации.

Например, `std.file.read_text` сейчас реализован через `host.file.read`, но owner у него `std`.

## Current Inventory

Актуальный machine-readable источник:

```text
tools/s-effects.rkt
```

Человекочитаемый вывод:

```bash
just effects
```

Consistency check:

```bash
just effects-check
```

Он сверяет inventory с текущими `runtime` и `checker` call patterns.

## Freeze rule

Новый effect нельзя добавлять только правкой runtime.

Нужны:

- обновление `tools/s-effects.rkt`;
- зелёный `just effects-check`;
- spec/doc;
- runnable task или пример;
- test;
- S Machine trace или effect explanation;
- решение owner/status/kind.

Подробнее: [Runtime Freeze](../start/runtime-freeze.md).

## Current decisions

### host.*

`host.*` является bootstrap-only.

Он не должен быть целевым стилем пользовательского S.

План: переносить user-facing возможности в `std.*`.

### std.*

`std.*` является user-facing API.

Текущий статус v0.1: stable для уже перечисленных функций.

### world.*

`world.*` является protocol-v0.

Он отвечает за воспроизводимые world actions, state, trace и replay.

### visual.*

`visual.*` является protocol-v0.

Он отвечает за backend-neutral visual trace, а не за HTML/canvas renderer.

## Не входит в v0

- actor fabric effects;
- hardware effects;
- storage effects beyond `host.file.read`/`std.file.read_text`;
- network effects;
- permissions;
- effect capabilities;
- effect type system.
