# Верстак

Инструменты разработки, которыми пользуются автор и агенты. В релизный пакет
не входят. Промежуточные файлы и логи пишутся в `.cache/build/workbench/`.

```text
workbench/
├── check/          проверки: их зовут just, global-check и CI
│   └── view/       вид global-check: карточки, чек картинкой, PNG
├── agent/          инструменты агента: lens и сервер MCP saltic_*
├── bench.saltic    таблица лидеров по скорости
├── registry.saltic сверка реестра адаптеров
├── release-draft.saltic
├── stamp.saltic
├── kit.saltic      общее у проверок, bootstrap и tests
└── vscode/         расширение VS Code
```

## check/ — проверки

| Программа | Что делает |
|---|---|
| `global-check.saltic` | Одна проверка всего, `just global-check`: по очереди — сборка проверок, лимиты канона, самосборка полки с паспортами и время/память против прошлого прогона; затем разом — тесты на rv32i, x86-64 и rv64, тесты ОС, платформы (qemu-virt, UEFI, closure), самосборка на RV64, кодировщик x86. Вид — карточки «подготовка», «проверки разом», «итог»; в CI — без цвета, раз в 10 с «идут». Журналы — `.cache/build/workbench/check-*.log`. Вызывается и в CI релиза |
| `limits.saltic` | Лимиты канона, `just limits` и первый шаг `global-check`: до 512 строк кода и до 32 строк шапки. Замер и сверка — `limits/canon.saltic` (его же берёт `lens check`), известные нарушения — `limits-known.txt` (правит автор): им нельзя расти |
| `same.saltic` | `just same [исходники…]`: рефакторинг компилятора — исходники, собранные компилятором с полки и новым stage-1 под rv64, x86_64 и rv32i, совпадают побайтово; плюс набор ошибок канона |
| `same-source.saltic` | `just same-source`: правка исходников без изменения смысла — все программы собираются компилятором из HEAD и из рабочего дерева и сравниваются побайтово |
| `x86-encoder-golden.saltic` | `just x86-golden [--print]`: эталоны кодировщика x86-64 — каждую команду из `tests/x86-encoder.saltic` собирает GNU `as` и сверяет байты |
| `rva23/` | Таблица команд RV64 (RVA23): генератор `rva23.saltic` для компилятора и сверка с GNU-ассемблером |
| `view/cards.saltic` | Вид `global-check`: палитра логотипа, карточки, полосы веток и отрезки случаев, пиксельный логотип |
| `view/receipt.saltic` | Чек картинкой: строки терминала с цветом → пиксели (Spleen 8×16) → PNG в `чеки/` (вне git) |
| `view/png.saltic` | Кодировщик PNG с палитрой: deflate с готовыми кодами Хаффмана, CRC32 через `bits32` |

## agent/ — инструменты агента

| Программа | Что делает |
|---|---|
| `lens.saltic` | Saltic смотрит на свой код: `check` (разбор, чекер, лимиты; модуль без `program` — не ошибка), `api` (лицо модуля), `find` (где имя). Само зрение — `lens/look.saltic` |
| `mcp.saltic` | Сервер MCP по stdio, `just lens-serve` (.mcp.json и запись пользователя): инструменты `saltic_check`, `api`, `find`, `build`, `edit`, `rename`, `run`, `test`. Правка и переименование с проверкой — `mcp/edit.saltic`, запуск и тесты — `mcp/run.saltic`. Проверку зовёт `lens` дочерним процессом: JSON из craft и selfhost в одной программе не живут (общие варианты enum) |

## В корне

| Программа | Что делает |
|---|---|
| `bench.saltic` | `just bench`: таблица лидеров по скорости — задачи из `docs/numbers/benchmarks` на Saltic и на всех языках, что есть на машине; лучшее из 3 запусков, пик памяти, вывод сверен с Си -O2. Итог — `.cache/build/workbench/bench.md` |
| `registry.saltic` | `just registry`: реестр адаптеров `registry/adapters.txt` — паспорт и его поля, `lens check` кода, эффекты и идентификаторы против кода; индекс — `registry/index.json`. Устройство — `registry/README.md` |
| `release-draft.saltic` | `just release-draft [F:B:C]`: черновик релиза по Football Versioning — коммиты с последнего тега по префиксам, счёт и раздел CHANGELOG в `.cache/build/release-draft.md` |
| `stamp.saltic` | Время `[ЧЧ:ММ:СС]` у каждой строки вывода скриптов; провал команды — код 1 и «ошибка: StampedFailed» |
| `kit.saltic` | Общее у проверок, `bootstrap/` и `tests/`: строка со временем, запуск, сравнение файлов по байтам, сортировка, хвост журнала. `use workbench.kit` |

Тяжёлые проверки (`global-check`, `same`, `same-source`) запускает автор.
