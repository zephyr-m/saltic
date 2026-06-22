# S Machine v0

Этот документ фиксирует первый контракт исполнения S.

Статус: архитектурный контракт, не полноценная VM.

## Зачем

S не должен навсегда оставаться тем, что случайно умеет Racket bootstrap runtime.

Но писать полноценную VM сейчас рано.

Поэтому сначала фиксируется S Machine:

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

## Effects

Effect — это выход S Machine за пределы чистого вычисления.

Текущие группы effects:

```text
host.*
std.*
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
