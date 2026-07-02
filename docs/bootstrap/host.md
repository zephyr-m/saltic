# Host intrinsics

`host.*` — это временный слой Racket bootstrap.

Это не стандартная библиотека S и не финальный дизайн языка. Это честное имя для операций, которые сейчас выполняются host-средой, чтобы ранние программы на S могли делать полезные вещи до появления module/import системы и настоящей `std`.

Общая карта слоёв описана в [Библиотечной архитектуре](../start/libraries.md).
Минимальный канон будущей `std` описан в [std v0.1](../spec/std-v0.1.md).

## Зачем нужен host

Без `host.*` ранний S мог бы только считать выражения и печатать демонстрационные строки.

С `host.*` можно проверить реальные сценарии:

- прочитать файл;
- вывести результат;
- посчитать строки;
- проверить передачу CLI-аргументов в `main`;
- нарастить cookbook на маленьких рабочих примерах.

## Текущее подмножество

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

## Правило

`host.*` можно использовать в bootstrap-примерах и тестах.

Обычные пользовательские и canonical examples должны идти через `use std` и `std.*`.

Если возможность уже выглядит как обычный пользовательский API, её место в `std`, а не в `host`.
