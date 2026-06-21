# Physical world emulation

S движется не только к языку программирования.

Цель — эмуляция физического мира, внутри которой можно работать, строить, измерять, проверять и жить как в основной среде.

## Главный сдвиг

Классический путь разработки:

```text
IDE -> code -> run -> inspect output
```

Целевой путь S:

```text
world -> act -> observe -> modify -> simulate -> persist
```

Код остаётся важным, но перестаёт быть единственным интерфейсом. Действие в мире должно быть таким же первичным, как текст программы.

## Зачем так

Если начать с обычного приложения, мы снова получим исторический путь: файлы, окна, форматы, редакторы, плагины, отдельные CAD, отдельные симуляторы, отдельные игровые движки и отдельные инструменты автоматизации.

S должен идти другим маршрутом.

Сначала строится воспроизводимая физическая среда:

- объекты;
- пространство;
- время;
- материалы;
- силы;
- ограничения;
- измерения;
- инструменты;
- агенты;
- история действий;
- симуляция.

Ключевой принцип для проектирования языка:

```text
Box = форма состояния в моменте
object identity = непрерывность вещи во времени
time = порядок переходов, который несёт среда
local rhythm = скорость локального времени объекта относительно среды
```

Подробнее: [Time and State v0](../spec/time-state-v0.md).

Затем программирование становится одним из способов воздействовать на этот мир, а не единственным способом существования системы.

## Что делает S

S должен делать действия в эмулированном физическом мире:

- воспроизводимыми;
- проверяемыми;
- наблюдаемыми;
- сохраняемыми;
- переносимыми в другие backend/runtime;
- потенциально переносимыми в физическую реальность.

Формула:

```text
S is not only for writing programs.
S is for making actions in a simulated physical world reproducible and inspectable.
```

## Слои

```text
core.math
core.units
core.geometry
core.numerics
core.graph
core.physics
core.engine
world.*
tool.*
agent.*
```

`core.engine` — фундамент интерактивной физической сцены.

`world.*` — конкретная поверхность эмулированного мира.

`tool.*` — инструменты действия внутри мира.

`agent.*` — агенты, которые действуют, наблюдают, планируют и проверяют.

## world.*

Черновая карта:

```text
world.scene
world.object
world.space
world.time
world.material
world.action
world.measure
world.simulate
world.history
world.save
```

Текущее runtime-подмножество:

```text
world.spawn(kind)
world.place(object, x, y)
world.move(object, dx, dy)
world.trace()
world.trace_text()
world.state()
world.state_text()
world.replay(trace)
```

Это ещё не физика и не графика. Это первый action/trace срез:

```text
object handle
world state
action log
trace output
state output
replay from trace
```

## tool.*

Инструменты внутри мира:

```text
tool.inspect
tool.measure
tool.select
tool.move
tool.join
tool.constraint
tool.build
tool.trace
```

## Отношение к коду

Текстовый S-код нужен для:

- точного описания действий;
- воспроизведения действий;
- проверки сценариев;
- автоматизации;
- генерации инструментов;
- обмена между агентами и человеком.

Но конечная среда не должна сводиться к редактированию файлов.

Сценарий может выглядеть как код:

```s
@box = world.spawn(Box)
world.place(box, point(0, 0, 0))
world.material(box, material.aluminum)
world.apply(box, force)
world.simulate(seconds(1))
```

Текущий исполняемый пример:

```s
program() {
    @box = world.spawn("box")
    world.place(box, 10, 20)
    world.move(box, 5, 0)
    world.trace()
    world.state()
    out none
}
```

Replay MVP:

```s
program() {
    @box = world.spawn("box")
    world.place(box, 10, 20)
    world.move(box, 5, 0)

    @trace = world.trace_text()
    @state = world.state_text()
    @replayed = world.replay(trace)

    host.io.println(state == replayed)
    out none
}
```

А может быть результатом действий в мире, которые S сохраняет как воспроизводимую историю.

## Основной принцип

Сначала мир и действия.

Код — способ сделать действия точными, проверяемыми и переносимыми.
