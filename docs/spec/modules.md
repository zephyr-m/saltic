# Modules v0.1

Этот документ фиксирует принятое решение по module/import системе S v0.1.

Цель: выбрать минимальный путь к `std`, не ломая текущий язык и не превращая bootstrap `host.*` в пользовательский API.

## Зачем нужны modules

Без module/import системы `std` остаётся только документом.

S должен уметь отличать:

- код текущего файла;
- стандартную библиотеку;
- bootstrap intrinsics;
- будущие внешние пакеты.

## Вариант A: явный `use`

```s
use std.io
use std.file
use std.str

program(path, needle) {
    @text = std.file.read_text(path)
    @ok = std.str.contains(text, needle)
    std.io.println(ok)
    out none
}
```

Плюсы:

- явно видно зависимости файла;
- хорошо масштабируется;
- привычно для большинства языков;
- checker может проверять, что модуль подключён.

Минусы:

- появляется новый top-level item;
- нужно решить, что делает `use`: только разрешает путь или ещё импортирует короткие имена.

## Вариант B: `std.*` всегда доступен

```s
program(path, needle) {
    @text = std.file.read_text(path)
    @ok = std.str.contains(text, needle)
    std.io.println(ok)
    out none
}
```

Плюсы:

- минимально для пользователя;
- не требует нового syntax прямо сейчас;
- `std.*` ведёт себя как встроенный namespace.

Минусы:

- хуже видно зависимости;
- сложнее отделить ядро языка от библиотеки;
- может стать скрытой магией.

## Вариант C: `use std`

```s
use std

program(path, needle) {
    @text = std.file.read_text(path)
    @ok = std.str.contains(text, needle)
    std.io.println(ok)
    out none
}
```

Плюсы:

- одна строка вместо нескольких;
- зависимости всё ещё видны;
- хороший компромисс для v0.1.

Минусы:

- менее точно, чем `use std.file`;
- позже всё равно может понадобиться module-level import.

## Решение

Для S v0.1 выбран Вариант C:

```s
use std
```

Правило:

- `use std` разрешает пути `std.io.*`, `std.file.*`, `std.str.*`, `std.num.*`, `std.group.*`, `std.json.*`;
- короткие имена не импортируются;
- `std` не является частью language core;
- `host.*` остаётся доступен только для bootstrap examples и tests.

Так S получает видимый пользовательский API без преждевременного package manager.

## Backlog реализации

Минимальный порядок:

1. [x] Parser: добавить top-level item `use std`.
2. [x] AST: представить import как `(use "std")`.
3. [x] Checker: разрешать `std.*` только если файл содержит `use std`.
4. [x] Runtime: сделать временный std bridge поверх `host.*`.
5. [x] Formatter: печатать `use std` в верхней части файла.
6. [x] Explain: показывать подключённые модули и `std` calls.

## Std bridge

Первый bridge может быть временным:

```text
std.io.println        -> host.io.println
std.file.read_text    -> std/file.s -> host.file.read
std.file.write_text   -> std/file.s -> host.file.write
std.json.encode       -> std/json.s -> host.json.encode
std.str.lines_count   -> std/str.s -> host.str.lines_count
std.str.len           -> std/str.s -> host.str.len
std.str.join          -> host.str.join
std.str.add           -> std/str.s -> host.str.join
std.str.eq            -> std/str.s -> host.str.eq
std.str.contains      -> std/str.s -> host.str.contains
std.str.trim          -> std/str.s -> host.str.trim
std.str.upper         -> std/str.s -> host.str.upper
std.str.lower         -> std/str.s -> host.str.lower
std.str.split         -> std/str.s -> host.str.split
std.num.parse         -> std/num.s -> host.math.parse
std.num.abs           -> std/num.s -> host.math.abs
std.num.round         -> std/num.s -> host.math.round
std.str.eq            -> host.str.eq
std.str.contains      -> host.str.contains
std.str.trim          -> host.str.trim
std.str.upper         -> host.str.upper
std.str.lower         -> host.str.lower
std.num.abs           -> host.math.abs
std.num.min           -> host.math.min
std.num.max           -> host.math.max
std.num.round         -> host.math.round
```

Это не перенос доменной логики в Racket. Это адаптер имён, чтобы пользовательский код писал `std.*`, а bootstrap runtime временно исполнял это через `host.*`.

Текущий bridge уже позволяет запускать:

```text
examples/canonical/text-auditor.std.s
examples/canonical/report-generator.std.s
```

## Local object modules v0

Для объектных листов появился минимальный локальный import:

```s
use objects.player
```

Он ищет файл рядом с текущим `.s` файлом:

```text
objects/player.s
```

Импортированный файл добавляет свои top-level объявления в программу: `enum`, `Box`, constants и `skill`.

Это не package system и не полноценная namespace-модель. Это первый рабочий способ вынести объект, его состояния и реакции в отдельный лист.

Импорты дедуплицируются по файлу в рамках одного expand.

Это нужно для diamond-import формы:

```text
fabric -> actor_a -> leaflet
fabric -> actor_b -> leaflet
```

`leaflet.s` должен попасть в итоговую программу один раз.

## Не входит в v0.1

- external packages;
- aliases вроде `use std.str as str`;
- wildcard imports;
- arbitrary relative imports;
- package manager;
- public/private exports.
