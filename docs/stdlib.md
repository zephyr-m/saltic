# Стандартная библиотека

Стандартная библиотека — это слой L2.

Она содержит базовые инструменты, необходимые почти любой программе.

## Принцип

Стандартная библиотека должна быть очевидной.

Если человек без интернета хочет открыть файл, вывести строку, получить время или сделать TCP-сервер, он должен быстро найти локальный пример и не вспоминать сложную иерархию API.

## Черновые модули

```text
std.io
std.file
std.time
std.math
std.str
std.net
std.json
std.process
std.agent
std.render
```

## Пример

```s
use std.io
use std.time

skill main() {
    std.io.println("hello, S")
    @now = std.time.now()
    out none
}
```

## Правила

- L2 может зависеть от L1.
- L2 должна оставаться небольшой и надёжной.
- Доменные знания должны жить в L3, а не раздувать стандартную библиотеку.

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
