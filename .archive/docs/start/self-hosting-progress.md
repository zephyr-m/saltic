# Saltic self-hosting progress

Status: native bootstrap in progress
Updated: 2026-07-26

## Current estimate

These are engineering estimates, not line-count metrics:

```text
Saltic-owned frontend/runtime:  58–68%
LLVM backend:                  45–50%
Complete cycle without Racket: 43–47%
```

The current working estimate toward honest self-hosting is **about 45%**.

## Proven vertical paths

The Saltic-owned compiler pipeline exists:

```text
Saltic source
  → scanner
  → parser
  → checker
  → IR
  → LLVM IR
  → Clang
  → native executable
```

The native executable does not require Racket or LLVM at runtime.
Racket is still required to launch the bootstrap compiler that produces LLVM IR.

## Saltic-owned frontend and runtime

Implemented in Saltic:

- scanner with source locations and diagnostics;
- parser and AST;
- semantic checker and scopes;
- compiler IR;
- runtime registry and IR runtime;
- variables and reassignment;
- local `skill` declarations, parameters and calls;
- arithmetic and comparisons;
- `if` and `drum` IR;
- `Group`, `Box` and VM support;
- core modules and syscall contracts.

The bytecode VM supports more language features than the LLVM backend. Do not
confuse VM coverage with native LLVM coverage.

## Native LLVM coverage

Proven through generated LLVM, Clang and executed native binaries:

- numeric and string literals;
- LLVM-safe string escaping for `\"`, `\\`, `\n` and `\t`;
- constant variables;
- compositional modules with globals, declarations, functions and `main`;
- native `skill` and `call`;
- string and numeric arguments;
- local numeric calculations;
- `+`, `-`, `*`, `/`;
- `>`, `<`, `==`;
- native `if` through `icmp` and `br`;
- native `drum` through `phi`, `icmp` and `br`;
- mutable numeric loop state through `phi`;
- numeric `Group` literals;
- `core.group.count`;
- `core.group.item`;
- immutable `core.group.add`;
- numeric `Box` declarations and native layouts;
- `Box` defaults, construction and field reads;
- field updates;
- returning a `Box` from a `skill`;
- passing, mutating and returning the same live `Box`;
- multiple field updates in one `skill`;
- composing one live `Box` through a chain of skills;
- calls with an arbitrary number of simple arguments;
- mixed `Box` layouts derived from declarations (`ptr`, `i32`, `%Group`);
- string field construction, read, update and output;
- string field mutation and Box chains through skills;
- embedded numeric Group fields with defaults and overrides;
- Group field replacement, count and item access;
- native mixed-value `Token` construction through `token_make`;
- tagged native `%Value { kind, type, data }` representation;
- all-eater Group literals containing numbers, strings, Boxes, Groups and none;
- `core.group.add` for numbers, strings and Boxes;
- recovery of usable numbers, strings, Boxes and nested Groups through item;
- Group and runtime index parameters in native skills;
- runtime `%Value.kind/type` validation for Group<Box> item access;
- recovery of a Token through a runtime index and immediate field access;
- native string length and byte traversal inside a scanner skill;
- heap-backed Token and Group allocation across a skill boundary;
- persistent Group<Token> accumulation through a runtime loop;
- first native scanner slice returning durable Token data;
- native whitespace skipping with line and column tracking;
- native word and number boundary detection;
- first canonical keyword classification (`program` versus identifier);
- complete canonical keyword classification;
- complete canonical one-byte symbol classification;
- exact heap-backed token value slices;
- string output through libc;
- process execution through libc.

Current bootstrap Group layout:

```llvm
%Value = type { i32, i32, i64 }
%Group = type { i32, [16 x %Value] }
```

Capacity is fixed at 16. Adding to a full Group returns a copy without the new
item. Dynamic storage is a future layout change.

## Permanent verification

Run the complete native suite with:

```bash
just native-test
```

Current expected result:

```text
numeric regression:    14/14
structural regression: 54/54
string regression:      8/8
native integration:    52/52
```

Native fixtures and their runner live only under `s/tests`.

## What is not native yet

The largest remaining gaps are:

- general typed value lowering instead of recognized bootstrap shapes;
- dynamically growing Groups;
- general dynamic Value flow beyond the proven Group<Box> skill shape;
- explicit type flow for Box parameters and results instead of bootstrap inference;
- complete canonical scanner coverage for keywords, symbols, strings and comments;
- module loading and `use` lowering;
- native file primitives;
- complete diagnostics and error propagation;
- enough LLVM coverage to compile the compiler itself;
- a native `saltic build` CLI;
- the fixed-point self-hosting check.

## Completion condition

Native programs are not self-hosting by themselves. Self-hosting is complete
only when the cycle closes:

```text
bootstrap compiler A
  → builds native Saltic compiler B
  → compiler B builds compiler C
  → B and C agree on behavior/artifacts
```

At that point Racket becomes historical bootstrap infrastructure rather than a
required part of the working Saltic toolchain.
