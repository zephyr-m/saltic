# VM Step v0

Этот документ фиксирует контракт одного шага S VM.

Статус: карта переноса `tools/s-vm.rkt` -> S VM на S.

## Зачем

Сейчас смысл инструкции живёт в Racket:

```text
tools/s-vm.rkt -> run-function -> step!
```

Это место решает, что значит:

```text
(push 10)
(store "x")
(add)
(call "core.io.println" 2)
```

Self-hosting начинается не тогда, когда мы пишем больше `.s` файлов, а тогда, когда смысл этих инструкций постепенно переезжает из `step!` в S-код.

## Runtime State

Минимальная модель шага:

```text
StepInput:
  program
  frame
  instruction
  vm_state

StepOutput:
  next_frame
  next_vm_state
  optional_return
  optional_vm_error
```

В текущем Racket VM это размазано по mutable state:

- `frame`: function name, params, code, env, ip;
- local operand `stack`;
- shared `vm-state`: visual trace, world objects, world events;
- output port для `core.io.println`;
- hidden Racket exception для `return`.

S VM должна сделать эти части явными через `Box` values.

## Instruction Groups

### Group A: Pure Stack

Кандидаты на первый перенос в S.

```text
push
push-none
push-error
push-enum
load
store
pop
```

Почему первые:

- не требуют protocol boundary;
- не требуют nested code execution;
- почти полностью выражаются через `Frame`, `Stack`, `Env`.

Текущий tiny VM уже покрывает близкую форму:

```text
PUSH
LOAD
STORE
```

### Group B: Pure Math And Compare

Кандидаты на второй перенос.

```text
add
sub
mul
div
eq
gt
lt
```

Особое правило:

```text
div by zero -> error.DivisionByZero value
```

а не hidden VM crash.

Текущий tiny VM уже покрывает:

```text
ADD
SUB
MUL
DIV
```

Но ещё не покрывает:

```text
eq
gt
lt
error.DivisionByZero
```

### Group C: Structured Values

```text
group
box-new
field
```

Эта группа зависит от нормальной S-side модели `Group` и `Box` value.

Bootstrap implementation:

- `TinyGroup` поддерживает 0-2 значения;
- `TinyBox` поддерживает 0-2 поля;
- `field` возвращает value поля или `TinyError { name = "UnknownField" }`.

Это временная лестница до нормальной динамической памяти.

### Group D: Local Control

```text
if
drum
switch
rescue
return
```

Эта группа требует:

- nested bytecode body;
- явный return value вместо Racket exception;
- branch execution через `step` loop;
- error value matching.

Bootstrap implementation:

- `TinyBody` поддерживает 1-4 инструкции;
- `if` снимает test value со stack;
- если test равен `yes`, выполняет `TinyBody`;
- body получает текущие stack/env/result/returned и возвращает обновлённый frame.
- `drum` снимает count со stack и выполняет `TinyBody` count раз;
- bootstrap `drum` пока ограничен 0-4 итерациями.
- `switch` снимает value со stack и выбирает case по `TinyEnum.variant_name` или `TinyError.name`;
- `TinySwitch` поддерживает 1-2 case.
- `rescue` снимает value со stack;
- если value является `TinyError`, временно кладёт его в env под именем `target` и выполняет `TinyBody`;
- если value является non-error typed value, кладёт исходное value обратно на stack.

Ограничения:

```text
env binding restore пока не реализован
non-error primitive number/string path пока не типизирован
```

### Group E: Calls And Boundaries

```text
call
```

`call` является самым жирным местом, потому что через него проходят:

- local skill/function calls;
- `core.*`;
- `host.*`;
- `visual.*`;
- `world.*`.

Эта инструкция должна остаться boundary дольше остальных.

Bootstrap implementation:

- `CallKind.LOCAL` и `CallKind.BOUNDARY` разделяют local call и host/protocol boundary;
- `instr_call_local(name, argc)` создаёт local call;
- `instr_call_boundary(name, argc)` создаёт boundary call;
- `TinyFunction` описывает callable function: name, params, body;
- `TinyProgram` хранит 1-2 tiny functions;
- `run_tiny_with_functions(bytecode, functions)` запускает bytecode с function table;
- local `call` создаёт новый frame, bind-ит 0-2 arguments в env, выполняет function body и кладёт result на caller stack;
- `BoundaryTable` хранит S-side `Group` boundary handlers;
- boundary `call` ищет handler в `BoundaryTable`;
- `core.io.println` остаётся host effect, но dispatch к нему больше не hardcoded прямо в `step_tiny`;
- `core.group.count` и `core.group.at` представлены как S-side boundary handlers for `TinyGroup`;
- `core.str.trim`, `core.str.upper` и `core.str.lower` представлены как S-side boundary handlers for string helpers;
- `visual.trace_text` и `world.trace_text` представлены как S-side protocol boundary handlers.

Правильная цель:

```text
S VM handles call frame mechanics
host boundary handles only real host effects
```

Неправильная цель:

```text
S wrapper -> same giant Racket call dispatcher
```

## First Transfer Target

Первый честный перенос из Racket:

```text
Group A + Group B subset
```

На практике это значит расширить tiny VM так, чтобы она умела исполнять структурно близкие инструкции:

```text
push number/text/none/error/enum
load
store
pop
add/sub/mul/div
eq/gt/lt
return
```

И чтобы один маленький bytecode sample имел одинаковый результат:

```text
Racket VM result == S tiny VM result
```

## Non-Goals v0

Пока не переносим:

- parser;
- checker;
- module loader;
- full compiler;
- visual/world protocol internals;
- full `call` dispatcher;
- file IO.

## Done Criteria

Шаг считается сделанным, когда:

- есть S-модуль VM core, где `step_tiny` покрывает Group A/B;
- есть traced режим, который показывает frame до/после шага;
- есть пример, который исполняется и обычным Racket VM, и S tiny VM;
- Racket implementation остаётся reference, а не единственным носителем смысла этих инструкций.
