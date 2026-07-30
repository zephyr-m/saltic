# Arithmetic Interaction Bridge

This experiment fills the first half of the path from understandable arithmetic to
the fixed interaction-combinator chemistry.

## Source interaction system

Natural numbers are unary interaction trees:

```text
0 = ZERO
1 = S(ZERO)
n = S(...S(ZERO))
```

`ADD` has a principal first input and two auxiliary ports: second input and result.
It has exactly two local interaction rules:

```text
ADD >< ZERO  → connect second input directly to result
ADD >< S(x)  → S(ADD(x, second input))
```

These are source-level rules, not additions to the physical chemistry. They make the
meaning of arithmetic visible and testable before lowering.

## Completed path

```text
ADD(5, 3)
→ five ADD×S reductions
→ one ADD×ZERO reduction
→ S(S(S(S(S(S(S(S(ZERO))))))))
→ unary 8 / binary boundary 1000
```

`arithmetic_net.py` implements this graph literally. Each step removes one active pair
connected through principal ports and reconnects only its external wires.

## Deliberately unfinished path

```text
ADD / S / ZERO interaction system
→ Lafont translation
→ graph containing only γ / δ / ε
→ Logos-group protocol for each canonical rule
```

Lafont's universality theorem guarantees that such a translation exists, but its
construction uses codes, copiers, menus, selectors and a decoder. We do not replace
that construction with an unverified hand-written encoding. Until this lowering is
implemented and compared step-for-step, `5+3` is an interaction-net computation but
not yet a computation executed solely by the six physical combinator rules.

The unary chain may later be represented compactly by a Logos counter. That is a
representation optimization and must preserve the same observable reductions.

The no-shortcuts constructive compiler and its tested intermediate laws are
tracked in `LAFONT_COMPILER.md`.
