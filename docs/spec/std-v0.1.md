# std v0.1

Этот документ фиксирует минимальный черновик стандартной библиотеки S.

Это не реализация. Это канон того, как `std` должна выглядеть для первых полезных программ и куда должны переезжать возможности из `host`.

## Цель

`std` должна быть тем API, которое обычный пользователь S видит первым.

Если человек пишет программу на S без знания внутренностей bootstrap, он должен думать о `std`, а не о `host`.

## Граница

- `std` — пользовательская библиотека языка.
- `host` — временный bootstrap слой текущего backend/runtime.
- `std` не должна содержать доменную логику.
- `host` не должен выглядеть как финальный пользовательский API.

## Минимум v0.1

```text
std.io
std.file
std.str
std.num
std.group
```

`std.time` может быть следующим шагом, но не обязан быть частью первого канона.

Минимальный дизайн подключения принят в [Modules v0.1](modules.md): `use std`.

## Что должно уметь `std` v0.1

Набор специально маленький. Его достаточно для простых файловых, текстовых и числовых задач.

## Покрытие v0.1

| API | Status | Backend сейчас | Runtime test |
| --- | --- | --- | --- |
| `std.io.println(...)` | implemented | `host.io.println` bridge | yes |
| `std.file.read_text(path)` | implemented | `host.file.read` bridge | yes, через canonical |
| `std.str.lines_count(text)` | implemented | `host.str.lines_count` bridge | yes |
| `std.str.lines(text)` | implemented | `host.str.lines` bridge | yes |
| `std.str.len(text)` | implemented | `host.str.len` bridge | yes |
| `std.str.join(...)` | implemented | `host.str.join` bridge | yes |
| `std.str.add(...)` | implemented | `host.str.add` bridge | yes |
| `std.str.eq(left, right)` | implemented | `host.str.eq` bridge | yes |
| `std.str.contains(text, needle)` | implemented | `host.str.contains` bridge | yes |
| `std.str.trim(text)` | implemented | `host.str.trim` bridge | yes |
| `std.str.upper(text)` | implemented | `host.str.upper` bridge | yes |
| `std.str.lower(text)` | implemented | `host.str.lower` bridge | yes |
| `std.str.split(text, separator)` | implemented | `host.str.split` bridge | yes |
| `std.num.parse(text)` | implemented | `host.math.parse` bridge | yes |
| `std.num.abs(value)` | implemented | `host.math.abs` bridge | yes |
| `std.num.min(...)` | implemented | `host.math.min` bridge | yes |
| `std.num.max(...)` | implemented | `host.math.max` bridge | yes |
| `std.num.round(value)` | implemented | `host.math.round` bridge | yes |
| `std.group.count(group)` | implemented | runtime native | yes |
| `std.group.at(group, index)` | implemented | runtime native | yes |

Отложено за пределы первого фактического набора:

| API | Status | Причина |
| --- | --- | --- |
| `std.str.first_word(text)` | planned | слишком частная операция до появления общего `split` |

## Что пока остаётся в host

```text
host.io.println
host.file.read
host.str.lines_count
host.str.lines
host.str.len
host.str.join
host.str.add
host.str.eq
host.str.contains
host.str.trim
host.str.upper
host.str.lower
host.str.split
host.math.parse
host.math.abs
host.math.min
host.math.max
host.math.round
host.debug.show
```

Если функция уже нужна пользователям как обычный API, она должна иметь ясный путь из `host` в `std`.

`std` подключается через:

```s
use std
```

## Правила переноса

- `host.file.read` должен стать основой для `std.file.read_text`.
- `host.io.println` должен стать основой для `std.io.println`.
- `host.str.*` должен постепенно уйти в `std.str.*`.
- `host.math.*` должен стать частью `std.num` или соседнего числового модуля.

Минимальный bridge уже реализован для первых canonical examples.

Канонические пользовательские примеры должны писаться через `std.*`:

```text
examples/canonical/text-auditor.std.s
examples/canonical/report-generator.std.s
```

Примеры, которые напрямую используют `host.*`, считаются bootstrap-примерами, а не целевым стилем S.

## Что не входит в v0.1

- network stack;
- JSON;
- process management;
- CLI framework;
- logging framework;
- collection operations beyond `std.group.count` and `std.group.at`;
- package manager;
- domain-specific libraries;
- любое API, которое существует только ради одного примера.

## Критерий готовности

`std v0.1` станет каноном, когда можно будет написать простую программу, где:

- читается файл;
- разбирается текст;
- считается число;
- результат печатается через `std.io`;
- пользователь не видит `host` в обычном коде.
