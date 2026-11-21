# Craft

Инструменты разработчика, протоколы и прикладные знания, которые работают
поверх языка. Подключаются по корню `craft`: `use craft.testing`.

## Живое

- `testing.saltic` — тестовый набор: `test_new`, `test_equal`, `test_yes`,
  `test_no`, `test_finish`. На нём стоят тесты в `tests/` и
  `soul/seed/proof/`.
- `protocols/data/json` — чтение и запись JSON (`reader`, `writer`, `value`,
  `number`, `text`).
- `protocols/data/json_rpc` — запросы, ответы и ошибки JSON-RPC поверх
  `json`. Проверяется `just test json-rpc`.
- `protocols/security/crypto` — сравнение секретов за постоянное время.
  Проверяется `just test crypto`.

## Заготовки

Нет. Пустые файлы, что размечали будущие модули (инструменты, `studio`,
протоколы по уровням, `science`, `technology`), — в `.archive/soul/craft/`
(решение автора 21.11.2026: муляж — не место модуля). Новый модуль появляется
здесь вместе с первым кодом.
