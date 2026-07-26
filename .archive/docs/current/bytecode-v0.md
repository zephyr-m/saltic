# Bytecode v0

Этот документ фиксирует текущий bytecode-контракт S VM.

Статус: исполняемый v0-контракт для `tools/s-vm.rkt` и будущей второй VM.

## Зачем

S bytecode должен перестать быть внутренней деталью Racket-файла.

Нужен контракт, который можно реализовать повторно:

```text
S source -> AST -> S bytecode -> VM
```

В будущем:

```text
S bytecode -> S VM written in S
S bytecode -> native/backend VM
S bytecode -> hardware/actor backend
```

## Program Layout

Текущий dump:

```text
function program()
  0: (push 10)
  1: (push 20)
  2: (add)
  3: (return)
```

Машинная форма пока S-expression:

```text
(function name (params...) (instructions...))
```

В программе есть:

- один entry function: `program`;
- ноль или больше user/core skills как functions;
- metadata уровня compiler: boxes, enums.

`Box` и `enum` declarations не являются runtime instructions.
Они используются compiler-ом для построения values и проверки field/variant layout.

## Execution Model

VM v0 — стековая машина.

У function есть:

- instruction pointer;
- local environment;
- operand stack;
- shared VM state.

VM state содержит:

- visual trace;
- world objects;
- world event/skill-call queue;
- world trace.

Function call создаёт новый local environment.
VM state общий для всех вызовов.

## Values

Минимальные runtime values:

```text
number
string
yes/no
none
Box value
Group value
error value
enum value
world ref
```

## S-Side Instruction Model

Первый tiny VM на S пока не читает полный bytecode dump.

Но он уже использует близкую структурную форму инструкции:

```s
PayloadKind = enum {
    NONE,
    NUMBER,
    TEXT,
}

Instr = Box {
    op = Op.NOP
    target = ""
    argc = 0
    payload_kind = PayloadKind.NONE
    number_value = 0
    text_value = ""
}
```

Это промежуточный мост:

```text
real bytecode instruction
-> structured S instruction Box
-> S tiny VM
```

Следующий шаг — постепенно сближать эту форму с `Bytecode v0`, а не держать отдельную игрушечную модель.

Текстовое представление:

```text
none
yes
no
Point {...}
Group(n)
error.Name
EnumName.Variant
.Variant
#world-id
```

## Instructions

### push

```text
(push value)
```

Кладёт literal value на стек.

Используется для:

- number;
- string;
- yes/no как boolean VM values.

### push-none

```text
(push-none)
```

Кладёт `none`.

### push-error

```text
(push-error name)
```

Кладёт error value:

```text
error.Name
```

### push-enum

```text
(push-enum enum variant)
```

Кладёт enum value.

Примеры:

```text
(push-enum "Status" "OK") -> Status.OK
(push-enum #f "OK")       -> .OK
```

### load

```text
(load name)
```

Кладёт значение local variable на стек.

Unknown variable является VM error.

### store

```text
(store name)
```

Снимает значение со стека и записывает в local environment.

Используется и для `@name = ...`, и для assignment.

### pop

```text
(pop)
```

Снимает верхнее значение со стека.

Используется для expression statements.

### add/sub/mul/div

```text
(add)
(sub)
(mul)
(div)
```

Снимают `left`, `right`, кладут результат.

Требуют numbers.

`div` при делении на ноль кладёт:

```text
error.DivisionByZero
```

а не бросает hidden VM exception.

### eq/gt/lt

```text
(eq)
(gt)
(lt)
```

Снимают `left`, `right`, кладут answer value.

`gt`/`lt` требуют numbers.

`eq` использует value equality текущей VM.

### call

```text
(call name argc)
```

Снимает `argc` arguments со стека, вызывает function/protocol/core call, кладёт результат.

Порядок аргументов сохраняется:

```text
push a
push b
call f 2
```

означает:

```s
f(a, b)
```

Call targets:

- local skill/function;
- selected `core.*`;
- selected `host.*`;
- selected `visual.*`;
- selected `world.*`.

Protocol calls остаются видимыми как `call`, например:

```text
(call "visual.square_bipyramid" 4)
(call "world.emit" 4)
```

Это важно: bytecode не прячет effects в специальные opcodes.

### box-new

```text
(box-new name (fields...))
```

Снимает значения полей со стека и создаёт Box value.

Порядок `fields` задаётся compiler-ом на основе Box declaration.

### field

```text
(field name)
```

Снимает Box value, кладёт значение field.

Если value не Box или field неизвестен, это VM error.

### group

```text
(group count)
```

Снимает `count` значений и создаёт Group value.

### if

```text
(if body-code)
```

Снимает test value со стека.

Если test truthy, выполняет `body-code`.

Если test false/no, ничего не делает.

S source не имеет ключевого слова `if`.
Это bytecode/AST имя для формы:

```s
(condition) {
    ...
}
```

### drum

```text
(drum body-code)
```

Снимает count со стека.

Требует non-negative integer.

Выполняет `body-code` count раз.

`drum` не создаёт скрытую tick/index переменную.

### switch

```text
(switch ((case tag body-code)...))
```

Снимает value со стека.

Выбирает первый case, где:

- enum value variant равен `tag`;
- или error value name равен `tag`.

Если case не найден, кладёт `none`.

Если case найден, выполняет `body-code`.
Body-code обязан оставить result value на стеке, если surrounding code ожидает значение.

### rescue

```text
(rescue err body-code)
```

Снимает value со стека.

Если value является `error.*`:

- временно связывает `err` с error value;
- выполняет `body-code`;
- результат body остаётся на стеке.

Если value не error:

- кладёт original value обратно на стек.

`rescue` не ловит host/VM crash.
Он работает с error values языка.

### return

```text
(return)
```

Снимает значение со стека и завершает текущую function.

## Protocol Calls v0

### core

VM поддерживает текущий whitelist:

```text
core.io.println
core.group.count
core.group.at
core.str.add
core.str.len
core.num.abs
core.num.round
```

Часть `core.*` понижается в S core skills.
Часть остаётся VM primitive до стабилизации data model.

### visual

Поддерживаемые visual calls:

```text
visual.sheet(kind)
visual.grid(size)
visual.square_bipyramid(name, height, base, color)
visual.rotate(name, axis, speed)
visual.present()
visual.trace()
visual.trace_text()
```

Они пишут backend-neutral visual trace.

### world

Поддерживаемые world calls:

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

`world.emit` кладёт object skill call в очередь.

`world.step` применяет очередь и пишет trace.

## Error Boundary

Есть два разных слоя ошибок:

```text
error.* value       часть языка
VM error/crash      ошибка исполнения VM или нарушенный контракт
```

Пример language error:

```text
10 / 0 -> error.DivisionByZero
```

Пример VM error:

```text
load unknown_name
field x on non-Box
wrong protocol argument type
```

`rescue` работает только с language error values.

## Contract vs Implementation Detail

Контракт:

- instruction names;
- stack effects;
- value categories;
- function layout;
- visible protocol calls;
- error-as-value semantics;
- `world.emit` + `world.step` queue semantics.

Implementation detail:

- Racket structs;
- exact internal hash/list storage;
- textual bytecode dump formatting;
- current implementation of `run-code!`;
- current names of helper functions inside `tools/s-vm.rkt`.

## Следующий Шаг

Перед S VM in S нужно сделать:

- bytecode examples as data;
- `Group` access enough to interpret instruction lists;
- stable representation for instructions in S;
- tests that compare Racket VM and future S VM on the same bytecode.
