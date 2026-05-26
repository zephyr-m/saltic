# Foundation v0.1

Этот документ фиксирует фундамент S перед первым `world MVP`.

Цель: не начинать физическую эмуляцию мира, пока базовые понятия языка, runtime, имён, interop и actions не имеют хотя бы чернового контракта.

## Зачем нужен foundation

S движется к среде:

```text
world -> act -> observe -> modify -> simulate -> persist
```

Если сразу начать строить `world.*`, не закрепив фундамент, появятся случайные решения:

- непонятно, что такое значение;
- непонятно, что такое объект мира;
- непонятно, как хранить ссылку на объект;
- непонятно, где `std`, где `sys`, где `c`;
- непонятно, что такое действие;
- непонятно, как повторить историю действий.

Foundation нужен, чтобы world MVP был маленьким, но не случайным.

## Program model

S-программа — набор declarations.

Минимальные declarations v0.1:

```text
const
enum
skill
```

Точка входа:

```text
program(...)
```

`program` — точка входа воспроизводимого сценария.

`skill` сейчас является вызываемым блоком поведения.

`out` возвращает значение из `skill`.

## Value model

Текущее подмножество:

```text
number
string
bool
none
enum
error
```

Перед world MVP нужны черновики:

```text
record / struct
list / array
handle / ref
```

Особенно важен `handle / ref`.

Пример:

```s
@box = world.spawn("box")
```

`box` здесь не просто строка и не копируемый объект. Это ссылка/handle на объект внутри world state.

## Error model

Сейчас есть:

```s
operation() rescue |err| {
    ...
}
```

И ошибки вида:

```text
error.DivisionByZero
```

Нужно зафиксировать:

```text
error.* — значение ошибки
rescue — обработка ошибочного результата
```

Для world MVP ошибки должны покрывать:

```text
error.ObjectNotFound
error.InvalidAction
error.ConstraintFailed
error.InvalidMaterial
error.SimulationFailed
```

## Namespace model

Текущая карта имён:

```text
host.*   временные Racket bootstrap intrinsics
c.*      будущий C interop
sys.*    низкоуровневый системный слой S
core.*   фундаментальные дисциплины и инструменты рассуждения
world.*  поверхность физической эмуляции
tool.*   инструменты действия внутри world
agent.*  агенты, которые наблюдают, планируют и действуют
std.*    будущий alias к core.informatics.std.*
```

Важно:

```text
std.* не является самостоятельным слоем
core.informatics.std.* — реальное концептуальное место стандартной библиотеки
```

## Interop model

`host.*` — временный bootstrap слой текущего Racket runtime.

`c.*` — будущий foreign interface к C ABI.

Правило:

```text
host.* и c.* помогают bootstrap, но не являются идентичностью языка.
```

Будущий путь:

```text
host.* -> c.* -> sys.* -> core.informatics.std.* -> std alias
```

## Library model

Слои:

```text
c.*
host.*
sys.*
core.*
core.informatics.*
core.informatics.std.*
world.*
tool.*
agent.*
```

`core.engine` — нижний фундамент интерактивной физической сцены.

`world.*` — конкретная поверхность эмулированного мира.

`tool.*` — инструменты действия.

## Action model

World должен строиться вокруг действий.

```text
action = намеренное изменение world state
```

Примеры:

```text
spawn object
place object
move object
set material
apply force
measure distance
simulate time step
save trace
```

Action должен быть:

- воспроизводимым;
- проверяемым;
- сериализуемым;
- наблюдаемым;
- пригодным для replay.

## Trace model

Trace — последовательность действий.

```text
trace = action*
state = apply(trace, initial_world)
```

Trace нужен, чтобы:

- повторить результат;
- сравнить два сценария;
- понять, что сделал агент;
- сохранить историю работы;
- перенести сценарий между backend/runtime.

Первый world MVP должен уметь хотя бы вывести trace в текстовом виде.

## World MVP preconditions

До первого world MVP надо иметь:

```text
[x] value model draft: handle/ref
[x] namespace model fixed enough for world/tool
[x] action shape draft
[x] trace shape draft
[x] minimal world state model
[ ] clear split: core.engine vs world.*
```

Первый world MVP не обязан иметь графику.

Минимальный проверяемый результат:

```text
создать объект
изменить его состояние действием
сделать simulate step
получить trace
повторить trace
получить тот же state
```

## Current Action / Trace MVP

Первый runtime-срез уже есть:

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

Команда:

```bash
just run-file examples/world-basic.s
```

Вывод:

```text
spawn #1 box
place #1 10 20
move #1 5 0
#1 box at 15 20
```

## Главный принцип

Мир нельзя строить как обычное приложение.

Мир строится как воспроизводимая система действий над физическим состоянием.
