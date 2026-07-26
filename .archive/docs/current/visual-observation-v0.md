# Visual Observation v0

Этот документ фиксирует первый визуальный протокол S.

Главная мысль:

```text
S не должен зависеть от браузера, HTML или привычных desktop-программ.
S должен уметь выдавать наблюдение состояния в нейтральном протоколе.
```

## Назначение

Visual observation — это не renderer.

Это маленький trace команд, который описывает, что нужно наблюдать:

```text
sheet engineering
grid 24
shape square_bipyramid crystal height 4 base 2 color cyan
motion rotate crystal y 1
present
```

Такой trace может быть исполнен разными backend:

- временный HTML/canvas preview на Linux;
- PNG preview;
- будущий display protocol S OS;
- framebuffer;
- GPU backend;
- удалённый frame stream для агента.

## Канон

S-программа не генерирует HTML как целевой формат.

S-программа порождает visual observation trace.

Backend выбирается после этого.

```text
S scene/state -> visual trace -> backend -> visible frame
```

## Текущий bootstrap API

В Racket bootstrap добавлен временный встроенный модуль `visual.*`.

```text
visual.sheet(kind)
visual.grid(size)
visual.square_bipyramid(name, height, base, color)
visual.rotate(name, axis, speed)
visual.present()
visual.trace()
visual.trace_text()
```

Это не финальная стандартная библиотека.

Это первый протокол наблюдения, чтобы проверить направление.

## Почему не core

`core.*` должен оставаться стандартной библиотекой обычной информатики.

Visual observation ближе к runtime/engine-среде:

```text
state -> observation
```

Поэтому текущий v0 использует `visual.*`, как отдельный встроенный протокольный слой.

## Почему не HTML

HTML может быть удобным временным preview.

Но он не является частью архитектуры S.

Для будущей ОС S нужен собственный путь:

```text
visual trace -> display protocol
```

## Первый primitive

Первый зафиксированный primitive:

```text
square_bipyramid
```

Он выбран потому что:

- его можно описать очень малым числом параметров;
- он похож на инженерный кристалл;
- вращение сразу показывает состояние во времени;
- он хорошо проверяет мост от текста к наблюдению.

## Не входит в v0

- HTML backend;
- canvas API;
- shader model;
- material model;
- camera model;
- lighting model;
- физически корректный рендер;
- scene graph;
- layout engine;
- units and dimensions;
- animation timeline.

## Следующий шаг

Следующий шаг после протокола:

```text
visual trace -> temporary preview
```

Preview может быть HTML только как текущий Linux-инструмент, а не как язык.
