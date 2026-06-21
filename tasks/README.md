# Tasks

`tasks/` — место для первых агентских заданий на S.

Задача — это папка с минимальным контрактом:

```text
tasks/<id-name>/
  task.md
  solution.s
  expected.txt
```

Обязательные файлы:

- `task.md` — человеческое описание задачи.
- `solution.s` — решение на S.

Опциональный файл:

- `expected.txt` — точный stdout, с которым сравнивается запуск.

Запуск:

```bash
just task tasks/001-finance-balance
racket tools/task.rkt --json tasks/001-finance-balance
```

`task` делает:

- checker для `solution.s`;
- explain summary;
- runtime запуск;
- сравнение stdout с `expected.txt`, если файл есть.

JSON-режим нужен агентам. Он возвращает один объект с результатами `check`, `explain`, `run` и `expected`.

Если задача стала полезным примером, её можно перенести в `examples/user/`, `examples/canonical/` или закрепить тестом.
