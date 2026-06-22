# Runtime Freeze

Этот документ фиксирует правила заморозки runtime.

Статус: working policy.

## Зачем

Racket runtime сейчас является bootstrap-слоем.

Он нужен, чтобы быстро проверять язык, задачи и вертикальные срезы.

Но runtime не должен превращаться в случайную свалку intrinsics.

Правило:

```text
runtime grows only through contract, task, test and trace
```

Если новая возможность не проходит этот gate, она не попадает в runtime.

## Текущий runtime v0.1 surface

Текущий runtime уже поддерживает:

```text
program
skill
out
var/bind
assign
if
switch
drum
rescue
number
string
yes/no
none
enum
Box
Group
```

Текущие effect/protocol groups:

```text
host.*
std.*
world.*
visual.*
```

Текущий machine contract:

```text
enter
bind
set
call
effect
return
halt
```

Подробнее: [S Machine v0](../spec/s-machine-v0.md).

## Freeze levels

### Soft freeze

Статус: можно вводить сейчас.

Runtime можно менять, но только если изменение проходит gate:

- есть spec/doc;
- есть runnable task или пример;
- есть test;
- есть machine trace или понятное effect-объяснение;
- понятно, почему это runtime, а не std/tool/backend;
- понятно, как это не ломает будущую actor fabric.

### Contract freeze

Runtime public behavior больше не ломается.

Можно:

- чистить внутреннюю реализацию;
- улучшать diagnostics;
- добавлять backend behind same contract;
- переносить host-детали под stable API.

Нельзя:

- менять смысл существующих конструкций;
- менять формат effect trace без миграции;
- добавлять новый intrinsic без нового contract decision.

### Hard freeze

Racket runtime перестаёт расширяться.

Новые возможности идут через:

- S std;
- world engine;
- visual backend;
- actor fabric simulator;
- S Machine/VM;
- hardware/backend layer.

Racket остаётся bootstrap implementation, а не местом роста языка.

## Intrinsic gate

Новый intrinsic разрешён только если все ответы ясны:

```text
1. Какую боль он закрывает?
2. Почему это не S-код?
3. Почему это не std?
4. Почему это не backend/tooling?
5. Какой task доказывает необходимость?
6. Какой test держит поведение?
7. Как он выглядит в S Machine trace?
8. Это effect или pure value operation?
9. Как он переносится в actor fabric?
10. Как он не закрывает путь к programmable matter?
```

Если хотя бы один ответ мутный, intrinsic откладывается.

## Effect groups

### host.*

Bootstrap-only.

`host.*` существует, чтобы текущий Racket runtime мог читать файлы, печатать и давать временные primitives.

Канон:

```text
host.* must not become user-facing S style
```

Пользовательские примеры должны постепенно переходить на `std.*`.

### std.*

Обычная стандартная библиотека.

`std.*` должен быть маленьким, очевидным и переносимым.

Если функция может быть обычной библиотекой, она не должна становиться runtime intrinsic без причины.

### world.*

Протокол действий и состояния мира.

`world.*` не должен становиться мешком доменной логики.

Он должен описывать воспроизводимые действия, trace и replay.

### visual.*

Протокол наблюдения.

`visual.*` не является HTML, canvas или renderer API.

Он должен выдавать backend-neutral visual trace.

### actor/fabric

Пока не runtime API.

Перед добавлением actor/fabric intrinsics нужно сначала сделать:

```text
Actor Fabric v0 -> S Machine mapping -> task -> test
```

## Запреты soft freeze

Не добавлять напрямую в runtime:

- случайные helpers ради одного примера;
- доменную логику;
- browser/HTML assumptions;
- desktop OS assumptions;
- hidden mutation;
- actor fabric до контракта;
- physical matter operations без safety model;
- удобные shortcuts, если они скрывают модель времени или сообщений.

## Что делать вместо роста runtime

Если хочется добавить runtime-фичу, сначала проверить альтернативы:

- можно ли написать это на S?
- можно ли оформить это как `std.*`?
- можно ли сделать tool?
- можно ли сделать task без новой фичи?
- можно ли выразить это через `world.*` или `visual.*` trace?
- нужно ли сначала обновить S Machine contract?

## Runtime freeze checklist

Перед contract freeze нужно иметь:

- effects inventory;
- S Machine trace для ключевых tasks;
- documented `host.*` migration plan;
- stable `std v0.1`;
- clear `world.*` boundary;
- clear `visual.*` boundary;
- no accidental browser dependency;
- no accidental CPU/VM dependency;
- green `just verify`;
- at least one agent-readable task flow.

## Next step

Следующий практический шаг после этого документа:

```text
effects inventory
```

Нужно перечислить все текущие effects:

```text
host.*
std.*
world.*
visual.*
```

И для каждого указать:

- статус;
- owner layer;
- tests;
- docs;
- migration/freeze decision.
