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
std.json
```

`std.time` может быть следующим шагом, но не обязан быть частью первого канона.

Минимальный дизайн подключения принят в [Modules v0.1](modules.md): `use std`.

## Что должно уметь `std` v0.1

Набор специально маленький. Его достаточно для простых файловых, текстовых и числовых задач.

## Покрытие v0.1

| API | Status | Backend сейчас | Runtime test |
| --- | --- | --- | --- |
| `std.io.println(...)` | implemented | `host.io.println` bridge | yes |
| `std.file.read_text(path)` | implemented | S std module over `host.file.read` | yes, через canonical |
| `std.file.write_text(path, text)` | implemented | S std module over `host.file.write` | yes |
| `std.json.encode(value)` | implemented | S std module over `host.json.encode` | yes |
| `std.str.lines_count(text)` | implemented | S std module over `host.str.lines_count` | yes |
| `std.str.lines(text)` | implemented | S std module over `host.str.lines` | yes |
| `std.str.len(text)` | implemented | S std module over `host.str.len` | yes |
| `std.str.join(...)` | implemented | `host.str.join` bridge | yes |
| `std.str.add(left, right)` | implemented | S std module over `host.str.join` | yes |
| `std.str.eq(left, right)` | implemented | S std module over `host.str.eq` | yes |
| `std.str.contains(text, needle)` | implemented | S std module over `host.str.contains` | yes |
| `std.str.trim(text)` | implemented | S std module over `host.str.trim` | yes |
| `std.str.upper(text)` | implemented | S std module over `host.str.upper` | yes |
| `std.str.lower(text)` | implemented | S std module over `host.str.lower` | yes |
| `std.str.split(text, separator)` | implemented | S std module over `host.str.split` | yes |
| `std.num.parse(text)` | implemented | S std module over `host.math.parse` | yes |
| `std.num.abs(value)` | implemented | S std module over `host.math.abs` | yes |
| `std.num.min(...)` | implemented | `host.math.min` bridge | yes |
| `std.num.max(...)` | implemented | `host.math.max` bridge | yes |
| `std.num.round(value)` | implemented | S std module over `host.math.round` | yes |
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
host.file.write
host.json.encode
host.str.lines_count
host.str.lines
host.str.len
host.str.join
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
- `host.file.write` должен стать основой для `std.file.write_text`.
- `host.json.encode` должен стать основой для `std.json.encode`.
- `host.io.println` должен стать основой для `std.io.println`.
- `host.str.*` должен постепенно уйти в `std.str.*`.
- `std.str.add` уже вынесен в S-модуль стандартной библиотеки и работает поверх `host.str.join`.
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
