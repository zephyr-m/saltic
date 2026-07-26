# S project structure freeze

Этот файл фиксирует целевую структуру self-hosting части проекта.

Правило:

```text
новая семантика сначала ищет существующий слот в этой карте
новый файл добавляется только если карта явно изменилась
```

Цель не в том, чтобы заранее написать весь toolchain.
Цель в том, чтобы дальнейшая работа не расползалась по случайным файлам.

## Stable Roots

```text
README.md                  вход в проект
Roadmap.md                 рабочая карта self-hosting
Structure.md               freeze целевой файловой структуры
docs/                      спецификации, контракты, рабочие планы
examples/                  runnable evidence
std/                       S standard library modules
tools/                     текущий Racket bootstrap/tooling
tests/                     Racket-based verification пока нет S runner
s/                         будущий S-owned toolchain/runtime
```

## Racket To S Ownership Map

Не каждый `tools/*.rkt` должен получить отдельный `.s` близнец.

Правило:

```text
tools/<command>.rkt         CLI wrapper, может остаться тонким wrapper-ом
tools/s-<domain>.rkt       semantic owner, должен иметь S-owned slot
```

Текущая карта:

```text
tools/s-runtime.rkt        -> s/runtime/runtime.s
tools/s-modules.rkt        -> s/runtime/modules.s
tools/s-effects.rkt        -> s/effects/effects.s
tools/s-effects-check.rkt  -> s/effects/check.s
tools/s-machine-trace.rkt  -> s/effects/machine_trace.s
tools/s-parser.rkt         -> s/compiler/syntax/parser.s
tools/s-checker.rkt        -> s/compiler/semantics/checker.s
tools/s-vm.rkt             -> s/vm/*
tools/s-vm.rkt bytecode    -> s/bytecode/*
tools/s-formatter.rkt      -> s/tooling/formatter.s
tools/s-explainer.rkt      -> s/tooling/explainer.s

tools/parse.rkt            -> CLI for parser
tools/check.rkt            -> CLI for checker
tools/run.rkt              -> CLI for runtime
tools/vm-run.rkt           -> CLI for VM
tools/effects.rkt          -> CLI for effects
tools/effects-check.rkt    -> CLI for effects checker
tools/format.rkt           -> CLI for formatter
tools/explain.rkt          -> CLI for explainer
tools/task.rkt             -> CLI for task runner
tools/machine-trace.rkt    -> CLI for machine trace
```

Project/app-specific tools are not part of the language core:

```text
tools/family-ledger-*.rkt
tools/ui-framebuffer.rkt
tools/package-vscode.rkt
```

## S-Owned Tree Runtime Slots

```text
s/runtime/runtime.s        tree-walking runtime semantics
s/runtime/value.s          runtime value helpers before/alongside VM value model
s/runtime/scope.s          lexical/local scope and assignment model
s/runtime/call.s           skill calls, object calls, arity conventions
s/runtime/core.s           core.* dispatch policy before it moves fully to std/
s/runtime/modules.s        module loading and object module lookup
s/runtime/world.s          world protocol runtime bridge/model
s/runtime/visual.s         visual protocol runtime bridge/model
```

Current owner:

```text
tools/s-runtime.rkt
tools/s-modules.rkt
```

Direction:

```text
tools/s-runtime.rkt -> s/runtime/*
```

## S-Owned VM Runtime Slots

```text
s/bytecode/literal.s       bytecode literal and payload records
s/bytecode/instruction.s   opcode, call kind, and instruction-as-data model
s/bytecode/program.s       program, skill layout, declarations, and validation adapter
```

Current owner:

```text
docs/spec/bytecode-v0.md
tools/s-vm.rkt bytecode dump
examples/bootstrap/tiny_vm/core.s Instr/TinyFunction/TinyProgram
```

Direction:

```text
tiny VM structural model -> s/bytecode/* -> compiler/VM shared contract
```

```text
s/vm/value.s               value model: none, number, text, error, enum, group, box
s/vm/instruction.s         instruction constructors and bytecode-as-data shape
s/vm/stack.s               operand stack operations
s/vm/env.s                 local binding environment
s/vm/frame.s               call frame and VM state records
s/vm/boundary.s            boundary table and host/protocol dispatch model
s/vm/step.s                single instruction step semantics
s/vm/interpreter.s         bytecode loop over frames and functions
s/vm/bytecode_data.s       loader/adapter from bytecode dump to S values
```

Current owner:

```text
examples/bootstrap/tiny_vm/core.s
tools/s-vm.rkt
```

Direction:

```text
core.s monolith -> s/vm/* modules
```

Until module loading is strong enough, `examples/bootstrap/tiny_vm/core.s` remains the runnable evidence file.

## S-Owned Compiler Slots

```text
s/compiler/main.s                    compiler entry contract and orchestration facade
s/compiler/lexer/token.s   token model
s/compiler/lexer/scanner.s scanner contract and future lexer helpers
s/compiler/syntax/ast.s              AST boxes/groups
s/compiler/syntax/parser.s           parser helpers, not full rewrite first
s/compiler/semantics/checker.s       checker helpers and local validations
s/compiler/bytecode/emitter.s        bytecode emitter
s/compiler/pipeline/pipeline.s       subset compile pipeline orchestration
```

Order:

```text
emitter -> AST transforms -> parser helpers -> checker helpers -> subset compiler
```

Do not start with a full parser rewrite.

## S-Owned Tooling Slots

```text
s/tooling/test_runner.s    future S test runner
s/tooling/formatter.s      future S formatter pieces
s/tooling/explainer.s      future S diagnostics/explain pieces
s/tooling/task_runner.s    future S task runner pieces
```

Current owner:

```text
tools/*.rkt
tests/*.rkt
justfile
```

## Host Boundary Slots

```text
s/host/boundary.s          minimal host primitive names and contracts
s/host/effects.s           effect records exposed to S-owned tooling
```

## Effects Slots

```text
s/effects/effects.s        effect inventory model
s/effects/check.s          effect checker rules
s/effects/machine_trace.s  machine/effect trace data
```

Current owner:

```text
tools/s-effects.rkt
tools/s-effects-check.rkt
tools/s-machine-trace.rkt
```

Host files are not a place to hide user-facing behavior.
They exist to name the minimal primitives that cannot yet live in S.

## When A New File Is Allowed

A new file is allowed only when one of these is true:

```text
new stable root is needed
new public spec contract is needed
existing slot would mix unrelated ownership
```

If that happens, update this file in the same change.
