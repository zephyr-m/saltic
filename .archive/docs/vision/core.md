# core

`core.*` — фундаментальные инструменты рассуждения и предметные дисциплины.

Они формализуют знания и операции как библиотеки уровня языка.

Общая карта слоёв описана в [Библиотечной архитектуре](../start/libraries.md).

## Черновые домены

```text
core.math
core.physics
core.chemistry
core.biology
core.geometry
core.logic
core.language
core.informatics
core.engine
core.history
core.geography
core.economics
```

## Пример

```s
use core.math
use core.physics

program() {
    @force = physics.force(mass, acceleration)
    @area = math.triangle(a, b, c)
    out none
}
```

## Зачем это нужно

S должен помогать строить системы без постоянного поиска справочников.

`core.*` может дать:

- формальные определения;
- распространённые константы;
- единицы измерения;
- проверенные операции;
- переиспользуемые модели предметных областей.

## Информатика

`core.informatics` — дисциплина вычислений.

Внутри неё живёт будущая стандартная библиотека:

```text
core.informatics.base
```

Подробнее: [core.informatics](informatics.md).

## Engine

`core.engine` — будущий общий фундамент для интерактивных физических сцен.

Он должен быть базой для игр, симуляций, визуальных редакторов и CAD-like workflows.

Сейчас отдельный `core.cad` не вводится: CAD-подобные инструменты должны вырасти поверх `core.engine`, `core.geometry` и `core.physics`.

Подробнее: [core.engine](engine.md).

## Ограничение

`core.*` не должен быть свалкой runtime-заглушек.

Низкоуровневые системные возможности живут в `sys.*`.

Временные bootstrap-возможности живут в `host.*`.

C interop живёт в `c.*`.

## Практическое ограничение v0.1

L3 — большая идея, но не первая реализация.

Для v0.1 достаточно держать это как vision и начать максимум с:

- `core.math`;
- `core.logic`.
- `core.informatics` как место будущей core.
- `core.engine` как будущий фундамент для игр, симуляций и CAD-like tooling.

Остальные домены не должны мешать MVP языка.
