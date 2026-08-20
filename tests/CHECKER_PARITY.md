# Сравнение чекеров

`bash tests/3-checker-parity.sh` строит один self-hosted checker и сравнивает его
с `js/2-checker.js` на двух явных входах:

- `canonical.s` — полная корректная программа;
- `tests/canonical-errors.s` — синтаксически корректная программа со всеми
  достижимыми из исходного текста семантическими ошибками host-чекера.

Промежуточные результаты не удаляются и находятся в
`.cache/build/checker-parity/`:

- `checker.s` — parser и checker с общей точкой входа;
- `checker.elf` — исполняемый RV32I checker;
- `ast/` — AST каждого варианта по данным host parser;
- `expected/` — диагностики `js/2-checker.js`;
- `actual/` — диагностики checker, написанного на Saltic;
- `diff/` — точное расхождение для каждого варианта.

Тест завершается на первом несовпадении и сообщает путь к сохранённому diff.
