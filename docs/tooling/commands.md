# Команды

Этот файл фиксирует текущие команды toolchain S.

## Основные команды

```bash
just
```

Показывает доступные команды.

```bash
just parse
just parse examples/basic.s
```

Парсит `.s` файл и печатает AST.

```bash
just test
```

Запускает тесты Racket.

```bash
just check
```

Парсит `examples/basic.s` и запускает первый semantic checker.

```bash
just format
just format-file examples/basic.s
```

Форматирует `.s` файл в официальном стиле.

```bash
just run
just run-file examples/basic.s
just run-file examples/count-lines.s docs/start/roadmap.md
just run-file examples/finance-log.s
just run-file examples/world-basic.s
just run-file examples/world-replay.s
```

Проверяет `.s` файл и запускает его через ранний Racket runtime.
Аргументы после имени `.s` файла передаются в параметры `program(...)`.

```bash
just example
```

Показывает основной пример и парсит `examples/basic.s`.

```bash
just docs
```

Показывает, где лежит документация.

```bash
code editors/vscode-s
```

Открывает локальное VS Code extension project для подсветки S. В открывшемся окне нажать `F5`, затем открыть `examples/basic.s` в Extension Development Host.

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
racket tools/parse.rkt examples/basic.s
racket tools/check.rkt examples/basic.s
racket tools/format.rkt examples/basic.s
racket tools/run.rkt examples/basic.s
racket tools/run.rkt examples/count-lines.s docs/start/roadmap.md
racket tools/run.rkt examples/finance-log.s
raco test tests
```

Эти команды полезны, когда нужно обойти `just` и увидеть низкоуровневое поведение.

## Explain

```bash
just explain examples/basic.s
just explain examples/finance-log.s
```

Показывает короткое человеческое описание `.s` файла:

```bash
just explain examples/finance-log.s
```

Это удобно, когда нужно понять программу без чтения Racket AST.

## Целевая форма будущей CLI

Позже эти команды могут стать командами единой утилиты `s`:

```bash
s parse examples/basic.s
s format examples/basic.s
s check examples/basic.s
s run examples/basic.s
s run examples/count-lines.s docs/start/roadmap.md
s test
s docs
s example
s explain examples/basic.s
```
