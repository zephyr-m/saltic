# Modules v0.1

Этот документ фиксирует принятое решение по module/import системе S v0.1.

Цель: выбрать минимальный путь к `core`, не ломая текущий язык и не превращая bootstrap `host.*` в пользовательский API.

## Зачем нужны modules

Без module/import системы `core` остаётся только документом.

S должен уметь отличать:

- код текущего файла;
- стандартную библиотеку;
- bootstrap intrinsics;
- будущие внешние пакеты.

## Вариант A: явный `use`

```s
use core.io
use core.file
use core.str

program(path, needle) {
    @text = core.file.read_text(path)
    @ok = core.str.contains(text, needle)
    core.io.println(ok)
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

## Вариант B: `core.*` всегда доступен

```s
program(path, needle) {
    @text = core.file.read_text(path)
    @ok = core.str.contains(text, needle)
    core.io.println(ok)
    out none
}
```

Плюсы:

- минимально для пользователя;
- не требует нового syntax прямо сейчас;
- `core.*` ведёт себя как встроенный namespace.

Минусы:

- хуже видно зависимости;
- сложнее отделить ядро языка от библиотеки;
- может стать скрытой магией.

## Вариант C: `use core`

```s
use core

program(path, needle) {
    @text = core.file.read_text(path)
    @ok = core.str.contains(text, needle)
    core.io.println(ok)
    out none
}
```

Плюсы:

- одна строка вместо нескольких;
- зависимости всё ещё видны;
- хороший компромисс для v0.1.

Минусы:

- менее точно, чем `use core.file`;
- позже всё равно может понадобиться module-level import.

## Решение

Для S v0.1 выбран Вариант C:

```s
use core
```

Правило:

- `use core` разрешает пути `core.io.*`, `core.file.*`, `core.str.*`, `core.num.*`, `core.group.*`, `core.json.*`;
- короткие имена не импортируются;
- `core` не является частью language core;
- `host.*` остаётся доступен только для bootstrap examples и tests.

Так S получает видимый пользовательский API без преждевременного package manager.

## Backlog реализации

Минимальный порядок:

1. [x] Parser: добавить top-level item `use core`.
2. [x] AST: представить import как `(use "core")`.
3. [x] Checker: разрешать `core.*` только если файл содержит `use core`.
4. [x] Runtime: сделать временный core bridge поверх `host.*`.
5. [x] Formatter: печатать `use core` в верхней части файла.
6. [x] Explain: показывать подключённые модули и `core` calls.

## Std bridge

Первый bridge может быть временным:

```text
core.io.println        -> host.io.println
core.file.read_text    -> core/file.s -> host.file.read
core.file.write_text   -> core/file.s -> host.file.write
core.json.encode       -> core/json.s -> host.json.encode
core.str.lines_count   -> core/str.s algorithm over len/at
core.str.lines         -> core/str.s algorithm over split
core.str.len           -> core/str.s -> host.str.len
core.str.at            -> core/str.s -> host.str.at
core.str.slice         -> core/str.s -> host.str.slice
core.str.join          -> host.str.join
core.str.add           -> core/str.s -> host.str.join
core.str.eq            -> core/str.s -> host.str.eq
core.str.is_empty      -> core/str.s algorithm over len
core.str.starts_with   -> core/str.s algorithm over len/slice/eq
core.str.ends_with     -> core/str.s algorithm over len/slice/eq
core.str.contains      -> core/str.s algorithm over len/slice/eq
core.str.trim          -> core/str.s -> host.str.trim
core.str.upper         -> core/str.s -> host.str.upper
core.str.lower         -> core/str.s -> host.str.lower
core.str.split         -> core/str.s algorithm over len/at/slice/group.append
core.group.append      -> runtime native storage primitive
core.num.parse         -> core/num.s -> host.math.parse
core.num.abs           -> core/num.s -> host.math.abs
core.num.round         -> core/num.s -> host.math.round
core.str.eq            -> host.str.eq
core.str.trim          -> host.str.trim
core.str.upper         -> host.str.upper
core.str.lower         -> host.str.lower
core.num.abs           -> host.math.abs
core.num.min           -> host.math.min
core.num.max           -> host.math.max
core.num.round         -> host.math.round
```

Это не перенос доменной логики в Racket. Это адаптер имён, чтобы пользовательский код писал `core.*`, а bootstrap runtime временно исполнял это через `host.*`.

Текущий bridge уже позволяет запускать:

```text
examples/canonical/text-auditor.core.s
examples/canonical/report-generator.core.s
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
- aliases вроде `use core.str as str`;
- wildcard imports;
- arbitrary relative imports;
- package manager;
- public/private exports.
