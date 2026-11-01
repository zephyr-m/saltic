# Craft

Инструменты разработчика, протоколы и прикладные знания, которые работают
поверх языка. Подключаются по корню `craft`: `use craft.testing`.

## Живое

- `testing.saltic` — тестовый набор: `test_new`, `test_equal`, `test_yes`,
  `test_no`, `test_finish`. На нём стоят тесты в `tests/` и
  `soul/seed/tests/`.
- `protocols/data/json` — чтение и запись JSON (`reader`, `writer`, `value`,
  `number`, `text`).
- `protocols/data/json_rpc` — запросы, ответы и ошибки JSON-RPC поверх
  `json`. Проверяется `just test json-rpc`.
- `tracer` — трассировщик: исполняет готовый ELF в собственной VM
  (`selfhost.vm`) и печатает вызовы и возвраты сразу, не накапливая журнал в
  памяти. Исходник трассируется командой `just trace путь.saltic`, готовый
  образ — `just trace-elf путь.elf`. Проверяется `just test tracer`.

## Заготовки

Пустые файлы, которые размечают будущее место модуля:

- инструменты: `debugger`, `profiler`, `linter`, `formatter`, `repl`,
  `language_server`, `disassembler`, `fuzzer`, `benchmark`, `inspector`,
  `ast_viewer`, `memory_viewer`, `test_runner`, `documentation`;
- `studio/` — среда разработки (`ide`);
- `protocols/` — по уровням: `hardware`, `link`, `network`, `transport`,
  `security`, `discovery`, `application`, `development`, а в `data` —
  `cbor`, `msgpack`, `protobuf`, `mime`, `uri`;
- `science/` — математика и физика;
- `technology/` — устройство железа: процессор, память, диск, экран,
  батарея.
