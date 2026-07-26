# Команды

Этот файл фиксирует текущие команды toolchain S.

## Основные команды

```bash
just
```

Показывает доступные команды.

```bash
just parse
just parse examples/bootstrap/basic.s
```

Парсит `.s` файл и печатает AST.

```bash
just test
```

Запускает тесты Racket.

```bash
just verify
```

Запускает общий тестовый набор и проверку canonical-примеров.

```bash
just canonical
```

Проверяет архитектурный контракт canonical `*.core.s`, запускает checker и исполняет текущие эталонные примеры.

```bash
just user-examples
```

Проверяет обычные пользовательские примеры из `examples/user/`: они должны импортировать `core`, не использовать `host.*`, проходить checker и запускаться.

```bash
just task tasks/001-finance-balance
racket tools/task.rkt --json tasks/001-finance-balance
```

Проверяет первое агентское задание: `task.md`, `solution.s` и опциональный `expected.txt`.
Флаг `--json` возвращает machine-readable результат для слабых агентов.

```bash
just check
just check-file examples/canonical/text-auditor.core.s
racket tools/check.rkt --json examples/user/finance-log.s
```

Парсит `examples/bootstrap/basic.s` и запускает первый semantic checker.
Флаг `--json` печатает machine-readable diagnostics для агентов.

```bash
just format
just format-file examples/bootstrap/basic.s
```

Форматирует `.s` файл в официальном стиле.

```bash
just run
just run-file examples/bootstrap/basic.s
just run-file examples/user/count-lines.s docs/start/roadmap.md
just run-file examples/user/finance-log.s
just run-file examples/bootstrap/world-basic.s
just run-file examples/bootstrap/world-replay.s
```

Проверяет `.s` файл и запускает его через ранний Racket runtime.
Аргументы после имени `.s` файла передаются в параметры `program(...)`.

```bash
just example
```

Показывает основной пример и парсит `examples/bootstrap/basic.s`.

```bash
just docs
```

Показывает, где лежит документация.

```bash
code editors/vscode-s
```

Открывает локальное VS Code extension project для подсветки S. В открывшемся окне нажать `F5`, затем открыть `examples/bootstrap/basic.s` в Extension Development Host.

```bash
just vscode-package
```

Собирает локальный VSIX-пакет расширения в `dist/`.

```bash
just vscode-install
```

Собирает и устанавливает расширение в обычный VS Code. После этого `.s` файлы открываются с подсветкой без `F5`.

Для иконки файла нужно один раз выбрать тему иконок:

```text
Developer: Reload Window
Preferences: File Icon Theme -> S Language Icons
```

В этом репозитории также есть workspace-настройки:

```json
{
  "files.associations": {
    "*.s": "s"
  },
  "workbench.iconTheme": "s-language-icons"
}
```

Это нужно потому, что расширение `.s` часто уже связано с assembly, и некоторые темы иконок показывают для него asm-иконку.

## Прямые Racket-команды

```bash
racket tools/parse.rkt examples/bootstrap/basic.s
racket tools/check.rkt examples/bootstrap/basic.s
racket tools/format.rkt examples/bootstrap/basic.s
racket tools/run.rkt examples/bootstrap/basic.s
racket tools/run.rkt examples/user/count-lines.s docs/start/roadmap.md
racket tools/run.rkt examples/user/finance-log.s
raco test tests
```

Эти команды полезны, когда нужно обойти `just` и увидеть низкоуровневое поведение.

## Explain

```bash
just explain examples/bootstrap/basic.s
just explain examples/user/finance-log.s
racket tools/explain.rkt --json examples/canonical/report-generator.core.s
```

Показывает короткое человеческое описание `.s` файла:

```bash
just explain examples/user/finance-log.s
```

Это удобно, когда нужно понять программу без чтения Racket AST.

`explain --json` печатает machine-readable summary программы: imports, top-level counts, entrypoint, skills и вызовы `core`/`host`/`world`/`visual`.

## Machine Trace

```bash
racket tools/machine-trace.rkt tasks/011-visual-observation-protocol/solution.s
```

Показывает первый static S Machine trace:

```text
step 1: enter program()
step 2: bind crystal = Crystal {}
step 3: call observe_crystal(crystal)
...
```

Это не VM и не runtime trace. Это проверка формы шагов перед будущей S Machine/VM.

## Effects

```bash
just effects
racket tools/effects.rkt
just effects-check
racket tools/effects-check.rkt
```

Печатает текущий явный список runtime effects и protocol calls:

```text
effect                   owner      status       kind    decision
host.io.println          bootstrap  implemented  effect  bridge to core.io.println
core.io.println           core        stable-v0.1  effect  user-facing print
world.spawn              world      protocol-v0  effect  world action trace
visual.square_bipyramid  visual     protocol-v0  effect  visual trace
```

Этот список нужен для runtime freeze: новый effect должен появляться через inventory, spec, task и test.

`effects-check` сверяет inventory с текущими call patterns в runtime и checker.

## Целевая форма будущей CLI

Позже эти команды могут стать командами единой утилиты `s`:

```bash
s parse examples/bootstrap/basic.s
s format examples/bootstrap/basic.s
s check examples/bootstrap/basic.s
s run examples/bootstrap/basic.s
s run examples/user/count-lines.s docs/start/roadmap.md
s test
s docs
s example
s explain examples/bootstrap/basic.s
```
