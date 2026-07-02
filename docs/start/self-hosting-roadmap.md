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
- VM v0.3: `Group`, `std.group.count/at`, `drum`;
- `just vm-run`, `just vm-bytecode`, `just vm-box`, `just vm-box-bytecode`, `just vm-group`, `just vm-group-bytecode`.

Оценка автономности на этом этапе:

```text
S autonomy: about 35-40%
Racket dependency: about 60-65%
```

Это не точная метрика, а рабочая оценка направления.

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
[done] std.io.println
[done] Box construction
[done] field access
[done] Group
[done] std.group.count / std.group.at
[done] drum
[next] switch
[next] rescue
[future] effects and protocols
[future] enough modules for project-scale code
```

Готово, когда:

- VM запускает отдельный набор canonical examples;
- VM запускает object examples с `Box` + `Group` + `drum`;
- VM может выполнить полезный tool вроде простого exporter-а.

Следующий практический шаг:

```text
VM v0.4: switch + rescue
```

## Stage 2. std moves to S

Цель:

```text
std.* = S code
host.* = minimal primitives
```

Статус:

```text
[done] std.str.add
[done] std.str.len
[done] std.str.trim
[done] std.str.upper/lower
[done] std.str.contains/eq/split/lines/lines_count
[done] std.num.parse/abs/round
[done] std.file.read_text/write_text
[done] std.json.encode
[pending] std.io.println, blocked by varargs
[pending] std.str.join, treated as low-level string primitive
[pending] std.num.min/max, blocked by varargs
[done] std.group.count/at in VM
[pending] std.group.* as S std module, blocked by Group being native storage
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
load
store
add/sub/mul/div
eq/gt/lt
call
pop
box-new
field
group
drum
return
```

Готово, когда:

- bytecode spec is stable enough to implement a second VM;
- bytecode dump can be used as a debugging artifact;
- runtime behavior is described through S Machine, not Racket implementation details.

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
VM v0.4: switch + rescue
```

Почему:

- `switch` нужен для enum-driven state/reaction code;
- `rescue` нужен для контролируемых ошибок;
- без этого VM не сможет запускать canonical/bootstrap examples ближе к текущему runtime.

Готово, когда:

- есть `examples/bootstrap/vm-control.s`;
- `just vm-control` выполняется;
- bytecode содержит switch/rescue или эквивалентные control instructions;
- `tests/vm.rkt` покрывает switch/rescue.
