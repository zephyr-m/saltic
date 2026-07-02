# Стандартная библиотека

Стандартная библиотека S концептуально живёт внутри информатики:

```text
core.informatics.std
```

Короткое имя `std.*` может стать alias к `core.informatics.std.*`.

Она содержит базовые инструменты, необходимые почти любой программе.

Общая карта слоёв описана в [Библиотечной архитектуре](../start/libraries.md).
Дисциплина информатики описана в [core.informatics](../vision/informatics.md).

## Принцип

Стандартная библиотека должна быть очевидной.

Если человек без интернета хочет открыть файл, вывести строку, получить время или сделать TCP-сервер, он должен быстро найти локальный пример и не вспоминать сложную иерархию API.

## Черновые модули

```text
core.informatics.std.io
core.informatics.std.file
core.informatics.std.path
core.informatics.std.time
core.informatics.std.str
core.informatics.std.mem
core.informatics.std.net
core.informatics.std.json
core.informatics.std.process
core.informatics.std.cli
core.informatics.std.test
core.informatics.std.log
```

В обычном коде после появления imports это может сокращаться до:

```text
std.io
std.file
std.str
std.cli
```

## Пример

```s
program() {
    std.io.println("hello, S")
    out none
}
```

## Статус v0.1

`std.*` пока не реализована как настоящая библиотека S.

Черновик канона v0.1 описан в [std v0.1](std-v0.1.md).
Это тот документ, который задаёт будущий пользовательский API; `host.md` описывает только временный bootstrap слой.

В текущем Racket bootstrap есть отдельный слой `host.*`. Это не стандартная библиотека языка, а временные intrinsics текущей host-среды, чтобы ранние `.s` программы могли читать файлы, печатать текст и проверять модель исполнения.

Будущая `std` должна быть написана и оформлена как часть `core.informatics` поверх стабильных низкоуровневых возможностей. До появления module/import системы нельзя честно говорить, что `std` уже существует.

Ожидаемый путь реализации:

```text
core.informatics.std.* -> sys.* -> c.* или native backend
std.*                  -> alias к core.informatics.std.*
```

## Текущее host-подмножество

Сейчас runtime поддерживает маленькую часть `host.*`, достаточную для первых полезных программ.

```text
host.io.println(...)
host.file.read(path)
host.str.lines_count(text)
host.str.len(text)
host.str.join(...)
host.str.eq(left, right)
host.str.contains(text, needle)
host.str.trim(text)
host.str.upper(text)
host.str.lower(text)
host.math.abs(value)
host.math.min(...)
host.math.max(...)
host.math.round(value)
host.debug.show(...)
```

Первый полезный пример:

```s
program(path) {
    @text = host.file.read(path)
    @count = host.str.lines_count(text)
    host.io.println(path, ": ", count, " lines")
    out none
}
```

Запуск:

```bash
just run-file examples/user/count-lines.s docs/start/roadmap.md
```

## Правила

- `core.informatics.std.*` может зависеть от `sys.*`.
- `std.*` должно быть коротким alias, а не отдельной архитектурой.
- Доменные знания должны жить в `core.*`, а не раздувать стандартную библиотеку.

## Offline cookbook

Для S нужна локальная книга рецептов:

```text
docs/cookbook/file-io.md
docs/cookbook/tcp-server.md
docs/cookbook/parse-json.md
docs/cookbook/make-cli.md
docs/cookbook/memory-buffer.md
docs/cookbook/state-machine.md
docs/cookbook/agent-loop.md
docs/cookbook/embedded-blink.md
```

Это важнее, чем большая магическая стандартная библиотека.
