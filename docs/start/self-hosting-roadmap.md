# Saltic self-hosting roadmap

Updated: 2026-07-26
Current progress: [Self-hosting progress](self-hosting-progress.md)

## Goal

The working Saltic toolchain must no longer require Racket:

```text
Saltic source
  → native Saltic compiler
  → LLVM IR
  → native executable
```

Self-hosting is complete only when a native Saltic compiler can build the next
native Saltic compiler and the cycle remains stable.

## Chosen path

The active bootstrap path is LLVM:

```text
Saltic frontend → Saltic IR → LLVM IR → native code
```

The bytecode VM remains useful as:

- an executable semantics reference;
- a debugging and differential-testing tool;
- a possible portable runtime target.

It is no longer the critical path to the first independent native compiler.

## Rules

Every self-hosting step must:

- move language meaning into Saltic, IR or the native backend;
- avoid adding new behavior to the Racket bootstrap;
- end with a permanent Saltic regression test;
- end with a native integration test when executable behavior changes;
- preserve one canonical path for each operation;
- remove superseded bootstrap code when the replacement is proven.

Racket may launch existing Saltic bootstrap code until the native compiler
exists. It must not gain new language semantics.

## Phase 1. Native computational core

Status: **bootstrap subset complete**.

```text
[done] numeric and string literals
[done] LLVM string escaping
[done] variables and reassignment
[done] compositional LLVM modules
[done] native skill and call
[done] string and numeric arguments
[done] local numeric calculations
[done] add / sub / mul / div
[done] gt / lt / eq
[done] if
[done] drum
[done] mutable loop value through phi
[done] process execution
```

This phase proves functions, memory, computation, branches and loops in native
Saltic programs.

## Phase 2. Native data model

Status: **in progress**.

```text
[done] numeric Group literal
[done] Group count
[done] Group item
[done] immutable Group add
[done] numeric Box layout
[done] Box construction and defaults
[done] field read
[done] field update
[done] return Box from skill
[done] pass, mutate and return a live Box
[done] multiple field updates
[done] compose Box through multiple skills
[current] explicit native value kinds
[next] string and Group fields in Box
[next] heterogeneous Group values
[future] dynamically growing Group storage
```

Current Group is a fixed bootstrap layout:

```llvm
%Group = type { i32, [16 x i32] }
```

Phase 2 is complete when compiler AST, tokens, diagnostics and scopes can be
represented without host-owned values.

## Phase 3. General LLVM lowering

Status: **not started as a general system**.

Current LLVM generation supports proven bootstrap shapes. It must become a
typed lowering pipeline that composes arbitrary valid IR:

```text
[next] explicit native value kinds
[next] typed local environment
[next] arbitrary nested calls
[next] arbitrary expression composition
[next] general control-flow blocks
[done] multiple skills and simple call chains
[next] general call graph
[next] predictable unsupported-form diagnostics
```

Phase 3 is complete when LLVM generation is driven by IR semantics rather than
recognizing specific source-program shapes.

## Phase 4. Native core boundary

Status: **partially available through libc**.

```text
[done] string output bootstrap
[done] process execution bootstrap
[next] file read
[next] file write
[next] command-line arguments
[next] allocation boundary
[next] native error and exit convention
[future] replace libc helpers where Saltic ownership is valuable
```

The boundary must remain small. Core algorithms belong in Saltic; only effects
that require the operating system belong at the native boundary.

## Phase 5. Modules and compiler artifacts

Status: **pending**.

```text
[next] lower `use` to a deterministic module graph
[next] compile multiple Saltic files as one unit
[next] stable symbol naming
[next] stable ABI between Saltic modules
[next] emit diagnostics without the bootstrap runtime
[next] native `saltic build source.s -o app`
```

Phase 5 is complete when a user can compile a multi-file Saltic program without
calling Racket directly.

## Phase 6. Compile the compiler

Status: **pending native coverage**.

The compiler is already written in Saltic. The remaining work is to make every
construct it uses available in the LLVM backend.

Recommended order:

1. token and diagnostic Boxes;
2. heterogeneous Groups;
3. scanner string/group operations;
4. parser AST construction;
5. checker scopes and diagnostics;
6. IR emitter;
7. LLVM emitter;
8. compiler CLI.

The first milestone is not the entire repository. It is one native compiler
binary capable of compiling the exact Saltic subset used by itself.

## Phase 7. Bootstrap closure

Status: **future**.

```text
compiler A (bootstrap)
  → compiler B (native Saltic)
  → compiler C (built by B)
```

Closure requires:

- B builds C successfully;
- B and C pass the same permanent tests;
- generated behavior is equivalent;
- ordinary Saltic builds no longer invoke Racket;
- Racket can be archived as the historical seed.

## Current next action

```text
Explicit native value kinds for structured data
```

Why this is next:

- numeric Box behavior is now proven end to end;
- compiler Boxes contain strings, Groups, none and nested structured values;
- current mutation lowering still infers a Box type from recognized fields;
- explicit value kinds remove that inference and unlock real compiler data.

Completion criterion:

```s
Token = Box {
    kind = ""
    value = ""
    line = 0
}

program() {
    @token = Token { kind = "NAME", value = "candy", line = 7 }
    out token.line
}
```

The program must preserve all three fields through construction, a skill call
and a field update. LLVM lowering must use explicit field kinds rather than
guessing the Box type from a field name.
