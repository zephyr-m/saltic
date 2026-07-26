# S Machine v0

Этот документ фиксирует первый контракт исполнения S.

Статус: архитектурный контракт и первый маленький VM-контур.

## Зачем

S не должен навсегда оставаться тем, что случайно умеет Racket bootstrap runtime.

Полноценную VM писать сразу рано.

Поэтому сначала фиксируется S Machine и маленький bytecode subset:

```text
S source -> S Machine steps -> effects/traces/messages -> backend
```

S Machine нужна как мост между:

- текущим Racket runtime;
- будущей VM;
- actor fabric;
- visual/world protocols;
- будущим hardware backend.

## Главная мысль

S Machine — это не обычный CPU.

Она описывает исполнение программы как последовательность наблюдаемых шагов:

```text
enter
bind
set
call
effect
return
halt
```

Позже эта модель должна расшириться до actor fabric:

```text
moment
actor step
inbox
reaction
outbox
history
observation
```

## Step v0

Минимальный шаг:

```text
step {
    index
    kind
    subject
    detail
}
```

Текущий текстовый вид:

```text
step 1: enter program()
step 2: bind crystal = Crystal {}
step 3: call observe_crystal(crystal)
step 4: enter observe_crystal(crystal)
step 5: effect visual.sheet("engineering")
step 6: effect visual.grid(24)
step 7: effect visual.square_bipyramid(crystal.name, crystal.height, crystal.base, crystal.color)
step 8: effect visual.rotate(crystal.name, "y", crystal.spin)
step 9: effect visual.present()
step 10: return none
step 11: effect visual.trace()
step 12: return none
step 13: halt
```

Это ещё не runtime trace.

Это первый static machine trace: программа разбирается, skills раскрываются, protocol calls видны как effects.

## Bytecode VM v0

Первый исполняемый VM-контур реализован отдельно от основного runtime:

```text
tools/s-vm.rkt
tools/vm-run.rkt
tests/vm.rkt
```

Запуск:

```bash
just vm-run
just vm-bytecode
```

Поддерживаемый subset v0.7:

- number/string/yes/no/none literals;
- локальные переменные через `@name = ...`;
- assignment;
- arithmetic/comparison binary ops: `+`, `-`, `*`, `/`, `==`, `>`, `<`;
- local `skill` calls;
- `Box` construction with defaults and overrides;
- field access through `object.field`;
- `Group` literals;
- `core.group.count(...)`;
- `core.group.at(...)`;
- `drum`;
- enum declarations and enum values;
- `switch`;
- `error.Name` values;
- `rescue |err| { ... }`;
- visual protocol calls: `visual.sheet/grid/square_bipyramid/rotate/present/trace/trace_text`;
- world event protocol calls: `world.spawn/emit/step/trace/trace_text/state/state_text/replay`;
- `core.io.println(...)`;
- `out`.

Пока не входит:

- modules beyond what compiler can load as ordinary top-level declarations;
- general `core.*` calls beyond the current VM whitelist.

## Error Values

В VM v0.4 ошибка не является скрытым исключением VM.

Она является обычным значением:

```s
error.DivisionByZero
```

Если выражение возвращает `error.*`, значение может:

- пройти дальше по стеку;
- быть напечатано как `error.Name`;
- быть обработано через `rescue`.

```s
@value = 10 / 0 rescue |err| {
    0
}
```

Это временно простая модель, но она согласуется с будущей физикой языка:

```text
error value now
-> world event later
-> actor/message reaction later
```

Ошибка не должна быть магией, спрятанной внутри host runtime.
Она должна быть наблюдаемой частью мира исполнения.

Минимальные opcodes:

```text
push
push-none
push-error
push-enum
load
store
add/sub/mul/div
eq/gt/lt
call
pop
box-new
field
group
if
drum
switch
rescue
return
```

Подробный контракт bytecode описан отдельно: [Bytecode v0](bytecode-v0.md).

Эта VM пока написана на Racket, но она уже отделяет S source от tree-walking runtime:

```text
S source -> AST -> S bytecode -> S VM
```

## Effects

Effect — это выход S Machine за пределы чистого вычисления.

VM v0.6 поддерживает первый исполняемый effect/protocol контур:

```text
visual.sheet(kind)
visual.grid(size)
visual.square_bipyramid(name, height, base, color)
visual.rotate(name, axis, speed)
visual.present()
visual.trace()
visual.trace_text()
```

Эти вызовы пишут backend-neutral visual trace.

Пример:

```text
sheet engineering
grid 24
shape square_bipyramid crystal height 4 base 2 color cyan
motion rotate crystal y 1
present
```

VM v0.7 добавляет минимальный world event protocol:

```text
world.spawn(kind)
world.emit(target, skill, ...)
world.step()
world.trace()
world.trace_text()
world.state()
world.state_text()
world.replay(trace)
```

`world.emit` не меняет состояние сразу.
Он кладет в очередь мира вызов skill у конкретного объекта.

`world.step` применяет очередь событий и пишет воспроизводимый trace:

```s
@box = world.spawn("box")
world.emit(box, "place", 10, 20)
world.emit(box, "move", 5, 0)
world.step()
```

Результирующий trace:

```text
spawn #1 box
place #1 10 20
move #1 5 0
```

Старые прямые вызовы `world.place` и `world.move` остаются bootstrap/runtime API, но канонический путь развития мира теперь идет через `emit/step`, где `place` и `move` понимаются как skills объекта.

Текущие группы effects:

```text
host.*
core.*
world.*
visual.*
```

В будущем часть effects должна стать:

```text
message emission
actor fabric event
storage operation
display protocol output
hardware operation
```

## Relation to Actor Fabric

S Machine не должна конкурировать с Actor Fabric.

Она должна стать мостом:

```text
S skill
-> S Machine call/effect
-> actor reaction/message
-> fabric delivery
```

В будущем `effect` может стать `emit leaflet`.

Но в v0 достаточно видеть, где программа производит внешний эффект.

## Relation to Runtime Freeze

Перед заморозкой runtime нужно понимать:

- какие шаги исполняются;
- какие effects создаются;
- где граница protocol layer;
- что должно быть воспроизводимо;
- что является частью языка, а что backend.

S Machine v0 является началом этого контракта.

Правила заморозки runtime описаны отдельно: [Runtime Freeze](../start/runtime-freeze.md).

## Current Tool

Текущий bootstrap tool:

```bash
racket tools/machine-trace.rkt tasks/011-visual-observation-protocol/solution.s
```

Он не исполняет программу.

Он строит static trace по AST и раскрывает вызовы `skill`.

## Не входит в v0

- bytecode;
- register machine;
- stack machine;
- GC;
- optimizer;
- scheduler;
- actor fabric simulator;
- real runtime tracing;
- binary format;
- ABI;
- memory layout;
- effect permissions.

## Следующий шаг

Следующий практический шаг:

```text
machine trace -> runtime trace
```

Но это стоит делать только после того, как static trace подтвердит полезную форму шагов.
