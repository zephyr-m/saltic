# Self-hosting roadmap

Этот документ фиксирует путь от текущего Racket bootstrap к состоянию, где рабочий контур S состоит из самого S.

Цель не в том, чтобы переписать всё сразу.

Цель:

```text
S source -> S compiler -> S bytecode -> S VM -> S std/tools
```

Racket должен постепенно стать только историческим bootstrap, а не рабочей средой языка.

## Текущее состояние

Сейчас:

```text
S source
-> Racket parser/checker
-> Racket tree-walking runtime
```

Уже начат переход:

```text
S source
-> Racket parser/checker
-> S bytecode
-> Racket implementation of S VM
```

Готово:

- S std modules: `std/file.s`, `std/json.s`, `std/num.s`, `std/str.s`;
- S tools in real projects: `geometry-paper/s/export_scene.s`;
- domain encoder on S: `geometry-paper/s/scene_json.s`;
- VM v0: numbers, strings, variables, skills, calls, arithmetic, `out`;
- VM v0.2: `Box` construction and field access;
- VM v0.3: `Group`, `core.group.count/at`, `drum`;
- VM v0.4: `error.*` values and `rescue`;
- VM v0.5: enum values and `switch`;
- VM v0.6: visual protocol effects;
- VM v0.7: world event protocol through `world.emit` + `world.step`;
- object skill call model v0 fixed in docs;
- bytecode v0 contract fixed in docs;
- first tiny VM interpreter sketch written in S: `examples/bootstrap/s-vm-tiny.s`;
- `just s-vm-tiny-vm` runs that S interpreter on the bytecode VM;
- tiny VM v0.2 covers `PUSH/LOAD/STORE/ADD/SUB/MUL/DIV/RETURN`;
- tiny VM v0.3 uses `Env` as an S `Box` with `env_load/env_store`;
- tiny VM v0.4 uses `Stack` as an S `Box` with stack helper skills;
- tiny VM v0.5 covers a minimal `CALL` convention for `core.io.println`;
- tiny VM v0.6 uses typed instruction payload: `PayloadKind`, `number_value`, `text_value`, `target`;
- tiny VM core moved into local S module: `examples/bootstrap/tiny_vm/core.s`;
- tiny VM v0.7 uses explicit `Frame` and `step_tiny(frame, instr)`;
- tiny VM debug layer moved into local S module: `examples/bootstrap/tiny_vm/debug.s`;
- VM step transfer contract fixed in docs: [VM Step v0](../spec/vm-step-v0.md);
- tiny VM v0.8 covers VM Step Group A/B subset: stack ops, math, compare, return, error/enum payloads;
- tiny VM v0.9 replaces hardcoded `Env { x, y }` with named S-side bindings;
- tiny VM v0.10 covers VM Step Group C bootstrap subset: `group`, `box-new`, `field`;
- tiny VM v0.11 starts VM Step Group D with `if` and `TinyBody`;
- tiny VM v0.12 adds bootstrap `drum` over `TinyBody`;
- tiny VM v0.13 adds bootstrap `switch` over `TinyEnum`/`TinyError`;
- tiny VM v0.14 closes VM Step Group D bootstrap subset with `rescue`;
- tiny VM v0.15 starts VM Step Group E with local tiny function calls;
- tiny VM v0.16 separates local calls from boundary calls with `CallKind`;
- tiny VM v0.17 adds an S-side boundary dispatch table for `core.io.println`;
- `just vm-run`, `just vm-bytecode`, `just vm-box`, `just vm-box-bytecode`, `just vm-group`, `just vm-group-bytecode`, `just vm-rescue`, `just vm-rescue-bytecode`, `just vm-control`, `just vm-control-bytecode`, `just vm-visual`, `just vm-visual-bytecode`, `just vm-world`, `just vm-world-bytecode`.

Оценка автономности на этом этапе:

```text
S autonomy: about 40%
Racket dependency: about 60%
```

Это не точная метрика, а рабочая оценка направления. Подробная шкала: [Autonomy score](autonomy-score.md).

## Principle

Каждый шаг self-hosting должен:

- уменьшать количество пользовательской логики в Racket;
- добавлять запускаемый пример или тест;
- не ломать основной runtime;
- фиксировать контракт в docs;
- переносить поведение в S, а не прятать его за wrapper.

Wrapper над host primitive не считается полноценным переносом, если смысл функции остаётся в Racket.

Нормальный перенос:

```text
std API -> S module -> minimal host primitive
```

Плохой перенос:

```text
std API -> renamed wrapper -> same Racket behavior
```

## Stage 1. VM becomes useful

Цель: VM должна исполнять не игрушечный subset, а основные формы S.

Статус:

```text
[done] numbers / strings / yes-no / none
[done] variables
[done] assignment
[done] skill calls
[done] arithmetic and comparisons
[done] core.io.println
[done] Box construction
[done] field access
[done] Group
[done] core.group.count / core.group.at
[done] if blocks
[done] drum
[done] error values
[done] rescue
[done] enum values
[done] switch
[done] visual effects/protocol calls
[done] world event protocol calls
[done] object skill calls
[next] boundary table expansion beyond core.io.println
[future] enough modules for project-scale code
```

Готово, когда:

- VM запускает отдельный набор canonical examples;
- VM запускает object examples с `Box` + `Group` + `drum`;
- VM может выполнить полезный tool вроде простого exporter-а.

Следующий практический шаг:

```text
Boundary table expansion beyond core.io.println
```

## Stage 2. std moves to S

Цель:

```text
core.* = S code
host.* = minimal primitives
```

Статус:

```text
[done] core.str.add
[done] core.str.len
[done] core.str.trim
[done] core.str.upper/lower
[done] core.str.contains/eq/split/lines/lines_count
[done] core.num.parse/abs/round
[done] core.file.read_text/write_text
[done] core.json.encode
[pending] core.io.println, blocked by varargs
[pending] core.str.join, treated as low-level string primitive
[pending] core.num.min/max, blocked by varargs
[done] core.group.count/at in VM
[pending] core.group.* as S std module, blocked by Group being native storage
```

Готово, когда:

- adding a user-facing std function usually means editing `.s`, not `s-runtime.rkt`;
- Racket runtime mostly contains `host.*`, VM, parser/checker/tooling;
- std modules are visible in docs and tests.

## Stage 3. Bytecode is the contract

Цель: S bytecode перестаёт быть внутренней деталью `tools/s-vm.rkt`.

Нужно зафиксировать:

- opcode list;
- instruction encoding;
- function layout;
- call convention;
- `Box` layout;
- `Group` layout;
- effect convention;
- error convention.

Текущие opcodes:

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

Готово, когда:

- bytecode spec is stable enough to implement a second VM;
- bytecode dump can be used as a debugging artifact;
- runtime behavior is described through S Machine, not Racket implementation details.

Текущий контракт: [Bytecode v0](../spec/bytecode-v0.md).

## Stage 4. S VM in S

Цель: написать простой interpreter bytecode на S.

Первый вариант может быть медленным.

Контур:

```text
Racket VM runs vm/interpreter.s
vm/interpreter.s runs S bytecode as data
```

Это будет первая настоящая self-hosting петля исполнения.

Перед этим нужны:

- enough structured data to represent bytecode;
- file/text primitives stable enough for tools;
- error handling or at least predictable failure model.

Готово, когда:

- один и тот же bytecode можно выполнить Racket VM и S VM;
- результаты совпадают на тестовом наборе;
- S VM живёт в repo как обычная S-программа.

## Stage 5. Compiler pieces in S

Цель: переносить compiler pipeline:

```text
tokens -> AST -> checked AST -> bytecode
```

Порядок:

1. bytecode emitter on S;
2. simple AST transforms on S;
3. parser helpers on S;
4. checker helpers on S;
5. enough compiler to compile a subset of S.

Не начинать с полного parser rewrite.

Сначала нужно, чтобы S удобно работал с:

- text;
- groups;
- boxes;
- errors;
- files;
- deterministic tools.

Готово, когда:

- часть compiler pipeline запускается как S-tool;
- Racket compiler вызывает S-coded compiler steps;
- S-coded steps покрыты tests.

## Stage 6. Bootstrap closure

Цель:

```text
old compiler -> new compiler
new compiler -> new compiler
```

Если новый S compiler может собрать себя и свою std/VM, Racket больше не нужен в обычном рабочем контуре.

Racket может остаться как:

- historical bootstrap;
- compatibility runner;
- emergency reference implementation.

Рабочий контур должен стать:

```text
S compiler
S bytecode
S VM
S std
S tools
```

## Current next action

Следующий конкретный шаг:

```text
Extend S VM Step Group E boundary table
```

Group A/B/C уже покрыты в tiny VM bootstrap form:

```text
push / load / store / pop
add / sub / mul / div
eq / gt / lt
return
group / box-new / field
```

Следующий слой:

```text
VM Step Group E: boundary table beyond core.io.println
```

Контракт: [VM Step v0](../spec/vm-step-v0.md).

Почему:

- Group A/B/C/D уже покрыты в tiny VM bootstrap form;
- tiny VM уже умеет local function call mechanics;
- local/boundary calls уже разделены явно;
- `core.io.println` уже проходит через S-side boundary table;
- Racket всё ещё хранит смысл остальных std/protocol/host boundary effects;
- без расширения boundary table новые host calls снова начнут расползаться в `step_tiny`.

Готово, когда:

- tiny VM имеет отдельную boundary dispatch table/model;
- `core.io.println` перестаёт быть hardcoded branch прямо внутри `step_tiny`;
- есть пример, где boundary call проходит через boundary model;
- следующий boundary handler выбран явно;
- Racket `step!` остаётся reference implementation, а не единственным носителем смысла этих инструкций.
