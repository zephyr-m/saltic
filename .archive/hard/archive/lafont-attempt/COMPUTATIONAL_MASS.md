# Computational Mass Foundation

Status: stable foundation. Changes below this line require an explicit architecture
revision; ordinary work should add protocols, compilers and bug fixes above it.

## Layer 0 — Logos physics

Normative source: `LOGOS_SPEC.md`.

```text
64-bit local counter
66-bit sticker: NOP / INC / DEC / HALT + 64-bit data
inbox / outbox with ready-valid backpressure
local zero/nonzero reactions
```

This layer defines how one physical entity changes. It knows nothing about graphs,
arithmetic, displays, operating systems or interaction combinators.

## Layer 1 — Computational mass

A finite collection of Logos and a transport that delivers stickers. Mass may be
implemented by silicon cells, an FPGA, a VM, an old computer, a drone or another
carrier, provided that its externally visible Logos semantics are identical.

Changing the amount or carrier of mass may change time, capacity and energy cost. It
must not change the result of a closed deterministic computation.

## Layer 2 — Interaction agent

One logical graph agent is initially represented by a group of counter-based Logos:

```text
TYPE STATE PRINCIPAL AUX_1 AUX_2 LOCK PAYLOAD
```

The grouping is a protocol-level representation. A future physical implementation may
pack these counters into one cell without changing the observable graph semantics.

## Layer 3 — Universal interaction chemistry

The fixed agent alphabet is Lafont's interaction combinators:

```text
γ  constructor, arity 2
δ  duplicator,  arity 2
ε  eraser,      arity 0
```

There are exactly six unordered active pairs:

```text
γγ  δδ  εε      annihilation
γδ  γε  δε      commutation
```

Only agents joined through principal ports interact. The six graph rules are fixed and
are not extended for calculators, games, AI or operating systems. Physical execution
of one rule may require many Logos stickers and transaction phases; these phases are
an implementation of the rule, not additional graph rules.

Reference: Yves Lafont, “Interaction Combinators”, Information and Computation 137
(1997), pp. 69–101, DOI 10.1006/inco.1997.2643.

## Layer 4 — Programs

A program is an initial interaction graph plus boundary inputs. Computation is local
graph reduction. A terminating program reaches a normal form; a service, game or OS
may remain a continuously interacting graph.

```text
S source
→ compiler
→ γ/δ/ε graph
→ reduction on computational mass
→ binary boundary result
```

ZephyrZero is the first intended compiled program. It must not introduce arithmetic
opcodes or calculator-specific interaction rules.

## Frozen principles

- Counters and interaction nets complement rather than replace one another.
- Logos physics does not depend on the program.
- The universal chemistry contains exactly three agents and six rules.
- Programs change graphs, not the underlying protocol.
- There is no mandatory global program counter or central graph reducer.
- Screen, text and human interfaces are boundary protocols, not computation.
- Optimizations may change representation, placement and scheduling only when they
  preserve the same graph reductions and boundary results.
