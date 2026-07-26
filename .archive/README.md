# Язык S

S — экспериментальный системный язык для автономной разработки, агентов и будущего собственного железа.

Главная причина существования S: нужен язык, на котором можно писать без интернета, без постоянного поиска синтаксиса и без копания в историческом багаже C. Язык должен быть достаточно простым, чтобы человек мог держать его в голове, а агент мог уверенно писать код без выбора между десятком равнозначных путей.

S берёт Zig как инженерную отправную точку, но не стремится быть просто переименованным Zig. Цель — первая итерация замены C для своей архитектуры, своих железок и агентной среды.

Так как собственной архитектуры пока нет, первая практическая цель — вырастить S внутри Racket: описать синтаксис, parser, AST, checker, formatter, раннее исполнение и bytecode VM. Backend под свою архитектуру остаётся долгосрочной целью.

Долгосрочная цель шире обычного языка программирования: S должен стать основой эмуляции физического мира, где работа происходит через действия, наблюдение, измерение, симуляцию и воспроизводимую историю изменений.

## Статус

S находится в исследовательской фазе `v0.1`.

Текущая практическая картина:

```text
S source
-> Racket parser/checker/runtime

S source
-> Racket parser/checker/compiler
-> S bytecode
-> Racket VM
-> S-side tiny VM semantics subset
```

Оценка автономности: около `40%`.

Пока ничего не стабильно:

- синтаксис может меняться;
- терминология может меняться;
- модель runtime может меняться;
- Racket является bootstrap-платформой и reference implementation для ранних версий S.

## Две главные цели

### 1. Автономность без интернета

Обычный код на S должен писаться по памяти.

Если для стандартной задачи нужно лезть в интернет, значит язык или его локальная документация не справились.

S должен быть маленьким языком с большим локальным набором инструментов, примеров и рецептов.

### 2. Агентный системный язык

S должен быть удобен для агентов.

Агент не должен выбирать между `for`, `while`, `loop`, `foreach` и ещё несколькими стилями. В языке должен быть один очевидный путь для базовой задачи.

Меньше выбора:

- меньше ошибок генерации;
- проще форматирование;
- проще статическая проверка;
- проще backend под свою ISA;
- проще сопровождение кода человеком.

## Принцип

```text
Меньше конструкций.
Меньше решений.
Больше предсказуемости.
```

S не пытается дать максимальную синтаксическую свободу. S пытается уменьшить нагрузку на память человека и нагрузку выбора для агента.

## Ранний пример синтаксиса

```s
MaxRetries = 3

skill divide(a, b) {
    (b == 0) {
        out error.DivisionByZero
    }

    out a / b
}

program() {
    @value = divide(10, 2) rescue |err| {
        host.io.println("error")
        0
    }

    drum (5) {
        host.io.println("tick")
    }

    out none
}
```

## Структура репозитория

```text
docs/              черновики спецификации
examples/          примеры кода на S
editors/vscode-s/  VS Code подсветка и иконка языка
brand/references/  визуальные референсы
drafts/            сырые заметки и исходный материал
```

## Документация

- [Индекс документации](docs/README.md)
- [Философия](docs/vision/philosophy.md)
- [Layers](docs/architecture/layers.md)
- [Bootstrap Contract](docs/bootstrap/bootstrap-contract.md)
- [v0.1 Core](docs/start/v0.1-core.md)
- [Грамматика](docs/current/grammar.md)
- [Команды](docs/tooling/commands.md)
- [Checker](docs/current/checker.md)
- [Синтаксис](docs/current/syntax.md)
- [Типы](docs/current/types.md)
- [Ошибки](docs/current/errors.md)
- [Runtime](docs/current/runtime.md)
- [Foundation](docs/start/foundation.md)
- [Библиотечная архитектура](docs/start/libraries.md)
- [C interop](docs/bootstrap/c-interop.md)
- [sys](docs/bootstrap/sys.md)
- [Host intrinsics](docs/bootstrap/host.md)
- [Стандартная библиотека](docs/current/core-library.md)
- [core v0.1](docs/current/core-v0.1.md)
- [core](docs/vision/core.md)
- [core.informatics](docs/vision/informatics.md)
- [core.engine](docs/vision/engine.md)
- [Physical world emulation](docs/vision/world.md)
- [agent](docs/vision/agent.md)
- [Racket Bootstrap](docs/bootstrap/racket.md)
- [Practice-first ограничения](docs/start/practice-first.md)
- [Self-hosting roadmap](docs/start/self-hosting-roadmap.md)
- [Autonomy score](docs/start/autonomy-score.md)
- [Дорожная карта](docs/start/roadmap.md)
- [Текущий рабочий план](docs/start/today.md)
- [Не цели](docs/vision/non-goals.md)

## Девиз

Build what holds.
