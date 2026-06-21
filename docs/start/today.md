# План на сегодня

Цель: превратить текущий вертикальный срез S в более удобный рабочий инструмент и подготовить следующий маленький шаг к `world MVP`.

Практическое ограничение: после `explain` и diagnostics следующий шаг должен дать полезную программу на S. Не начинать новый большой слой языка, пока не появится новый runnable пример из `docs/start/practice-first.md`.

## 1. `explain` — done

Сделать команду:

```bash
just explain examples/basic.s
```

Минимальный результат:

- показать top-level declarations;
- показать `program(...)`;
- показать `skill`-и и параметры;
- показать host/world вызовы;
- показать world actions;
- показать краткую сводку по AST без необходимости читать Racket datum.

Готово: `examples/basic.s` и `examples/world-basic.s` объясняются понятным текстом через `just explain <file>`.

## 2. Diagnostics v0.2 — done

Цель: начать сохранять позиции source-кода в ошибках checker.

Минимальный результат:

- parser уже знает `line` и `col`;
- нужно не терять их при переходе к AST/datum;
- checker diagnostics должны указывать строку и колонку хотя бы для неизвестного имени и неверного присваивания.

Готово: checker для файлов/строк теперь использует loc-AST и показывает `line:col` для неизвестного имени и неверного присваивания.

## 3. Практическая программа 1

Сделать первый новый полезный пример из текущего цикла.

Кандидат:

```text
examples/finance-log.s
```

Минимальный результат:

- программа считает итог прихода и расхода средствами S;
- программа запускается через `just run-file examples/finance-log.s`;
- программа объясняется через `just explain examples/finance-log.s`;
- Racket bootstrap не трогаем под доменную логику.

Готово: `examples/finance-log.s` считает баланс через `skill balance(income, expenses)` внутри S. Текстовый лог откладывается до появления итерации/разбора строк в самом S или будущей std.

## 4. World MVP 2

Расширить текущий action/trace срез.

Кандидаты:

```text
world.observe()
world.measure(a, b)
world.step()
world.remove(object)
```

Минимальный результат:

- добавить один новый action;
- добавить trace-запись;
- добавить replay;
- добавить runtime test;
- добавить пример в `examples/`.

## 5. Examples pack

Добавить маленькие программы, которые учат языку без чтения документации.

Кандидаты:

```text
examples/math.s
examples/strings.s
examples/errors.s
examples/world-measure.s
examples/world-step.s
```

Готово, когда каждый пример запускается через:

```bash
just run-file examples/<name>.s
```

## 6. Зафиксировать syntax decision

Текущий блок:

```s
(status) {
    .OK => host.io.println("ok"),
}
```

Нужно решить, как это называется в документации:

```text
switch
match
case block
choice
```

Готово, когда название и правило зафиксированы в `docs/spec/syntax.md` и `docs/spec/grammar.md`.
