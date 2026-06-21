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

Проверяет архитектурный контракт canonical `*.std.s`, запускает checker и исполняет текущие эталонные примеры.

```bash
just user-examples
```

Проверяет обычные пользовательские примеры из `examples/user/`: они должны импортировать `std`, не использовать `host.*`, проходить checker и запускаться.

```bash
just check
just check-file examples/canonical/text-auditor.std.s
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
```

Показывает короткое человеческое описание `.s` файла:

```bash
just explain examples/user/finance-log.s
```

Это удобно, когда нужно понять программу без чтения Racket AST.

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
