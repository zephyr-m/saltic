# Object Skill Call v0

Этот документ фиксирует минимальную модель object skill calls.

Статус: архитектурный контракт перед добавлением нового синтаксиса.

## Зачем

S движется к форме:

```s
box.move(5, 0)
```

Но сейчас точка уже означает доступ к полю:

```s
box.position.x
```

Поэтому нельзя вслепую добавить методы и превратить `Box` в class/object framework.

Сначала фиксируется смысл:

```text
target.skill(args...)
```

означает:

```text
send skill call to target object
```

а не:

```text
create Move event object
```

## Слои

```text
Box            форма состояния в моменте
world handle   identity объекта внутри world state
skill          допустимое действие/реакция объекта
emit           постановка skill call в очередь мира
step           применение очереди к world state
trace          воспроизводимая история применённых calls
```

Важно:

`move` не является объектом.

`move` является skill/action, который применяется к target.

## Current Surface

Текущая исполняемая форма:

```s
@box = world.spawn("box")
world.emit(box, "place", 10, 20)
world.emit(box, "move", 5, 0)
world.step()
```

Она читается как:

```text
box receives place(10, 20)
box receives move(5, 0)
world applies queued calls
```

## Future Sugar

Будущая пользовательская форма может выглядеть так:

```s
box.place(10, 20)
box.move(5, 0)
```

Она должна понижаться в:

```s
world.emit(box, "place", 10, 20)
world.emit(box, "move", 5, 0)
```

Это sugar над message/skill-call protocol, а не классический method call с hidden mutation.

## Why Not Event Object

Не это:

```s
Move {
    target = box
    dx = 5
    dy = 0
}
```

Для этого слоя `Move` как объект слишком рано.

Если сделать каждое действие объектом, модель быстро уйдёт в сторону event class hierarchy.

Текущий канон:

```text
object has skills
world queues skill calls
world.step applies calls
trace records applied calls
```

Позже payload может стать структурированным `Box`, если это потребуется для сложных аргументов.
Но сам action остаётся skill call, а не самостоятельной вещью.

## No Hidden Mutation

`box.move(5, 0)` не должен напрямую менять поле `box.x`.

Правильный путь:

```text
source form
-> world.emit(target, skill, args...)
-> world.step()
-> world state transition
-> trace line
```

Изменение состояния должно быть наблюдаемым через world trace.

## VM v0.7 Contract

VM v0.7 уже поддерживает:

```s
world.emit(target, skill, ...)
world.step()
```

Пример:

```text
examples/bootstrap/vm-world-emit.s
```

Trace:

```text
spawn #1 box
place #1 10 20
move #1 5 0
```

## Следующий Шаг

Добавлять синтаксис `target.skill(args...)` можно только после решения:

- как parser отличает field access от object skill call;
- может ли skill call возвращать значение;
- где объявляются skills объекта;
- как checker узнаёт, что target поддерживает skill;
- что происходит, если skill неизвестен;
- как это связано с object modules.

Минимальная цель следующего шага:

```text
target.skill(args...) -> world.emit(target, "skill", args...)
```

без изменения семантики `Box`.
