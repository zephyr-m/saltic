# Lafont compiler: constructive path

This file records what is implemented and what is still missing. A stage is
complete only when its defining reduction law is executable as a test. No
application-specific interaction rule may be hidden in the compiler.

## Pure target

The target contains only `gamma`, `delta`, `epsilon`, wires, and free interface
ports. Its only computation is the six canonical rules in
`interaction_combinators.py`.

## Implemented constructive blocks

`interaction_combinators.py` has composable principal fragments and these
families from Lafont's figure 4:

- `M_n` and `M*_n`, recursively made from `gamma`;
- autodual `T_n`, recursively made from `delta`.
- general `T_{p,q}`, made from `T_{p+q}` and exactly `p` gamma cells.

The `n=0` base is an eraser and `n=1` is a wire. Executable tests for widths
0 through 8 prove:

1. `M_n` connected to `M*_n` normalises to `n` identity wires;
2. `T_n` connected to `T_n` normalises to `n` identity wires;
3. one `epsilon` at the root of `M_n` produces one `epsilon` at every output.
4. two `T_{p,q}` fragments swap the first `p` pairs and preserve the remaining
   `q` wires (tested for every `0 <= p,q <= 4`).
5. a three-entry menu connected to each of its three selectors preserves the
   selected closed package and completely erases the other two.

These are structural compiler components, not new reduction rules.

## Required next stages

1. Symbol codes, copiers, and a decoder for the `ZERO/S/ADD` interaction
   system.
2. Lowering of the source `ZERO/S/ADD` system.
3. Pure-combinator reduction of `5+3` and decoding of the normal form.
4. Lowering each combinator agent and rewrite transaction onto Logos v0 groups.

Until stages 1--3 are complete, `arithmetic_net.py` is readable source
semantics, not evidence that arithmetic already runs on the pure target.
