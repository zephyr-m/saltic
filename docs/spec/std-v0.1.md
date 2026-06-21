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
```

`std.time` может быть следующим шагом, но не обязан быть частью первого канона.

## Что должно уметь `std` v0.1

```text
std.io.println(...)
std.file.read_text(path)
std.str.lines(text)
std.str.trim(text)
std.str.split(text, separator)
std.str.first_word(text)
std.str.contains(text, needle)
std.num.parse(text)
std.num.abs(value)
```

Набор специально маленький. Его достаточно для простых файловых, текстовых и числовых задач.

## Что пока остаётся в host

```text
host.io.println
host.file.read
host.str.lines_count
host.str.len
host.str.join
host.str.add
host.str.eq
host.str.contains
host.str.trim
host.str.upper
host.str.lower
host.math.abs
host.math.min
host.math.max
host.math.round
host.debug.show
```

Если функция уже нужна пользователям как обычный API, она должна иметь ясный путь из `host` в `std`.

## Правила переноса

- `host.file.read` должен стать основой для `std.file.read_text`.
- `host.io.println` должен стать основой для `std.io.println`.
- `host.str.*` должен постепенно уйти в `std.str.*`.
- `host.math.*` должен стать частью `std.num` или соседнего числового модуля.

## Что не входит в v0.1

- network stack;
- JSON;
- process management;
- CLI framework;
- logging framework;
- collections beyond строковых операций;
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

