# Стандартная библиотека

Стандартная библиотека S концептуально живёт внутри информатики:

```text
core.informatics.std
```

Короткое имя `core.*` может стать alias к `core.informatics.core.*`.

Она содержит базовые инструменты, необходимые почти любой программе.

Общая карта слоёв описана в [Библиотечной архитектуре](../start/libraries.md).
Дисциплина информатики описана в [core.informatics](../vision/informatics.md).

## Принцип

Стандартная библиотека должна быть очевидной.

Если человек без интернета хочет открыть файл, вывести строку, получить время или сделать TCP-сервер, он должен быстро найти локальный пример и не вспоминать сложную иерархию API.

## Черновые модули

```text
core.informatics.core.io
core.informatics.core.file
core.informatics.core.path
core.informatics.core.time
core.informatics.core.str
core.informatics.core.mem
core.informatics.core.net
core.informatics.core.json
core.informatics.core.process
core.informatics.core.cli
core.informatics.core.test
core.informatics.core.log
```

В обычном коде после появления imports это может сокращаться до:

```text
core.io
core.file
core.str
core.cli
```

## Пример

```s
program() {
    core.io.println("hello, S")
    out none
}
```

## Статус v0.1

`core.*` пока не реализована как настоящая библиотека S.

Черновик канона v0.1 описан в [core v0.1](core-v0.1.md).
Это тот документ, который задаёт будущий пользовательский API; `host.md` описывает только временный bootstrap слой.

В текущем Racket bootstrap есть отдельный слой `host.*`. Это не стандартная библиотека языка, а временные intrinsics текущей host-среды, чтобы ранние `.s` программы могли читать файлы, печатать текст и проверять модель исполнения.

Будущая `core` должна быть написана и оформлена как часть `core.informatics` поверх стабильных низкоуровневых возможностей. До появления module/import системы нельзя честно говорить, что `core` уже существует.

Ожидаемый путь реализации:

```text
core.informatics.core.* -> sys.* -> c.* или native backend
core.*                  -> alias к core.informatics.core.*
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

- `core.informatics.core.*` может зависеть от `sys.*`.
- `core.*` должно быть коротким alias, а не отдельной архитектурой.
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
