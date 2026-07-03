# Checker

Checker — слой после parser.

Parser проверяет форму программы и строит AST.

Checker проверяет, что программа имеет базовый смысл.

## Команда

```bash
racket tools/check.rkt examples/bootstrap/basic.s
just check
```

Успешная проверка печатает:

```text
ok
```

Ошибки печатаются по одной строке:

```text
1:1: error: variable 'y' is not declared
```

Для агентов есть JSON-режим:

```bash
racket tools/check.rkt --json examples/user/finance-log.s
```

Успешная проверка:

```json
{"diagnostics":[],"ok":true}
```

Ошибка:

```json
{
  "ok": false,
  "diagnostics": [
    {
      "level": "error",
      "code": "core_not_imported",
      "message": "module 'core' is not imported; add 'use core'",
      "line": 2,
      "col": 5,
      "hint": "add `use core` at top level"
    }
  ]
}
```

JSON-режим сохраняет тот же exit code: `0`, если diagnostics пустые, и `1`, если есть ошибки.

## Текущие проверки

- неизвестное имя;
- повторное имя на верхнем уровне;
- повторное объявление переменной в одном scope;
- присваивание необъявленной переменной;
- запрет присваивания константе;
- запрет конфликта переменной с top-level именем;
- `out` только внутри `skill`;
- первое присваивание фиксирует простой тип переменной;
- повторное присваивание должно быть совместимо с типом;
- базовая проверка арифметических операторов и сравнений;
- enum variant должен существовать.

Checker также знает позиции source-кода для semantic diagnostics и может указывать строку и колонку ошибки.
Structured diagnostics дополнительно имеют `code` и, где возможно, `hint` для автоматического исправления.

## Намеренные ограничения

- Checker пока работает поверх printed AST, а не напрямую по typed AST structs.
- Вывод типа пока грубый: `number`, `string`, `none`, `yes/no`, enum и `unknown`.
- Возвращаемые типы `skill` пока не выводятся.
- `host.*` считается внешним bootstrap-путём; его базовые вызовы известны checker'у, но это не полноценный `core`.
