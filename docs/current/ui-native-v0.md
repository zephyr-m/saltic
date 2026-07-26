# S Native UI v0

Этот документ фиксирует первый минимальный UI-протокол S.

Главная мысль:

```text
S-native UI не является браузером, HTML, CSS или desktop toolkit.
S-программа описывает интерфейс нейтральным trace-протоколом.
Backend решает, как это показать.
```

## Назначение

`ui.*` нужен для простых панелей, форм и отчётов:

```text
panel family-ledger
text Family ledger
field amount label Amount
button add label Add
value free 151000
present
```

Это первый шаг к картинке языка без привязки к чужой программной среде.

## Канон

```text
S state -> ui trace -> backend -> visible panel
```

Backend может быть разным:

- текущий terminal preview;
- временное host-окно;
- framebuffer;
- S OS display protocol;
- удалённый UI stream для агента.

## Текущий bootstrap API

```text
ui.panel(name)
ui.text(value)
ui.field(name, label)
ui.button(name, label)
ui.value(name, value)
ui.present()
ui.trace()
ui.trace_text()
```

## Граница

`ui.*` не является `core.*`.

`core.*` содержит базовые инструменты информатики. `ui.*` описывает наблюдаемую
панель и относится к engine/display-среде.

## Не входит в v0

- layout engine;
- события ввода;
- focus model;
- стили;
- темы;
- координаты;
- анимации;
- widgets beyond text, field, button, value;
- browser backend;
- desktop toolkit binding.

## Первый пример

```bash
just family-ledger-ui
```

Он запускает S-программу:

```text
examples/apps/family-ledger/ui.s
```

Программа считает ledger и выдаёт UI trace.

