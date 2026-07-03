# core v0.1

Этот документ фиксирует минимальный черновик стандартной библиотеки S.

Это не реализация. Это канон того, как `core` должна выглядеть для первых полезных программ и куда должны переезжать возможности из `host`.

## Цель

`core` должна быть тем API, которое обычный пользователь S видит первым.

Если человек пишет программу на S без знания внутренностей bootstrap, он должен думать о `core`, а не о `host`.

## Граница

- `core` — пользовательская библиотека языка.
- `host` — временный bootstrap слой текущего backend/runtime.
- `core` не должна содержать доменную логику.
- `host` не должен выглядеть как финальный пользовательский API.
- `host` должен оставаться маленьким набором primitives, а алгоритмы должны переезжать в `.s` файлы стандартной библиотеки.

Правильное направление:

```text
std API -> S implementation -> minimal host primitive
```

Неправильное направление:

```text
std API -> renamed host/Racket implementation
```

## Минимум v0.1

```text
core.io
core.file
core.str
core.num
core.group
core.json
```

`core.time` может быть следующим шагом, но не обязан быть частью первого канона.

Минимальный дизайн подключения принят в [Modules v0.1](modules.md): `use core`.

## Что должно уметь `core` v0.1

Набор специально маленький. Его достаточно для простых файловых, текстовых и числовых задач.

## Покрытие v0.1

| API | Status | Backend сейчас | Runtime test |
| --- | --- | --- | --- |
| `core.io.println(...)` | implemented | `host.io.println` bridge | yes |
| `core.file.read_text(path)` | implemented | S std module over `host.file.read` | yes, через canonical |
| `core.file.write_text(path, text)` | implemented | S std module over `host.file.write` | yes |
| `core.json.encode(value)` | implemented | S std module over `host.json.encode` | yes |
| `core.str.lines_count(text)` | implemented | S algorithm over `core.str.len/at` | yes |
| `core.str.lines(text)` | implemented | S std module over `host.str.lines` | yes |
| `core.str.len(text)` | implemented | S std module over `host.str.len` | yes |
| `core.str.at(text, index)` | implemented | S std module over `host.str.at` primitive | yes |
| `core.str.slice(text, start, end)` | implemented | S std module over `host.str.slice` primitive | yes |
| `core.str.join(...)` | implemented | `host.str.join` bridge | yes |
| `core.str.add(left, right)` | implemented | S std module over `host.str.join` | yes |
| `core.str.eq(left, right)` | implemented | S std module over `host.str.eq` | yes |
| `core.str.is_empty(text)` | implemented | S algorithm over `core.str.len` | yes |
| `core.str.starts_with(text, prefix)` | implemented | S algorithm over `core.str.len/slice/eq` | yes |
| `core.str.ends_with(text, suffix)` | implemented | S algorithm over `core.str.len/slice/eq` | yes |
| `core.str.contains(text, needle)` | implemented | S algorithm over `core.str.len/slice/eq` | yes |
| `core.str.trim(text)` | implemented | S std module over `host.str.trim` | yes |
| `core.str.upper(text)` | implemented | S std module over `host.str.upper` | yes |
| `core.str.lower(text)` | implemented | S std module over `host.str.lower` | yes |
| `core.str.split(text, separator)` | implemented | S std module over `host.str.split` | yes |
| `core.num.parse(text)` | implemented | S std module over `host.math.parse` | yes |
| `core.num.abs(value)` | implemented | S std module over `host.math.abs` | yes |
| `core.num.min(...)` | implemented | `host.math.min` bridge | yes |
| `core.num.max(...)` | implemented | `host.math.max` bridge | yes |
| `core.num.round(value)` | implemented | S std module over `host.math.round` | yes |
| `core.group.count(group)` | implemented | runtime native | yes |
| `core.group.at(group, index)` | implemented | runtime native | yes |

Отложено за пределы первого фактического набора:

| API | Status | Причина |
| --- | --- | --- |
| `core.str.first_word(text)` | planned | слишком частная операция до появления общего `split` |

## Что пока остаётся в host

```text
host.io.println
host.file.read
host.file.write
host.json.encode
host.str.lines_count
host.str.lines
host.str.len
host.str.at
host.str.slice
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

Если функция уже нужна пользователям как обычный API, она должна иметь ясный путь из `host` в `core`.

`core` подключается через:

```s
use core
```

## Правила переноса

- `host.file.read` должен стать основой для `core.file.read_text`.
- `host.file.write` должен стать основой для `core.file.write_text`.
- `host.json.encode` должен стать основой для `core.json.encode`.
- `host.io.println` должен стать основой для `core.io.println`.
- `host.str.*` должен постепенно уйти в `core.str.*`.
- `core.str.lines_count` уже является S-алгоритмом поверх `core.str.len` и `core.str.at`.
- `core.str.add` уже вынесен в S-модуль стандартной библиотеки и работает поверх `host.str.join`.
- `core.str.is_empty`, `core.str.starts_with` и `core.str.ends_with` уже являются S-алгоритмами.
- `core.str.contains` уже является S-алгоритмом поверх `core.str.len`, `core.str.slice` и `core.str.eq`.
- `host.str.at` и `host.str.slice` считаются минимальными primitives для будущего lexer/parser на S.
- `host.math.*` должен стать частью `core.num` или соседнего числового модуля.

Минимальный bridge уже реализован для первых canonical examples.

Канонические пользовательские примеры должны писаться через `core.*`:

```text
examples/canonical/text-auditor.core.s
examples/canonical/report-generator.core.s
```

Примеры, которые напрямую используют `host.*`, считаются bootstrap-примерами, а не целевым стилем S.

## Что не входит в v0.1

- network stack;
- process management;
- CLI framework;
- logging framework;
- collection operations beyond `core.group.count` and `core.group.at`;
- package manager;
- domain-specific libraries;
- любое API, которое существует только ради одного примера.

## Критерий готовности

`core v0.1` станет каноном, когда можно будет написать простую программу, где:

- читается файл;
- разбирается текст;
- считается число;
- результат печатается через `core.io`;
- пользователь не видит `host` в обычном коде.
