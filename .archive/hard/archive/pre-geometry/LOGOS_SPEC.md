# Logos v0 — bit and clock specification

Status: frozen experimental baseline. This document defines the machine that the
reference VM and RTL must implement. Display, fonts, routing policy and Saltic are
clients of this machine, not hidden opcodes.

## Sticker

A sticker is exactly 66 bits:

```text
65       64 63                                                   0
+-----------+-----------------------------------------------------+
| opcode[1:0] | data[63:0]                                        |
+-----------+-----------------------------------------------------+
```

All integers are unsigned. When serialized to bytes, the sticker is encoded as a
two-bit opcode followed by an unsigned 64-bit big-endian data field. The enclosing
transport carries routing information; a target address is not part of the sticker.

| Bits | Name | Meaning |
|---|---|---|
| `00` | `NOP` | Consume the sticker; change nothing. |
| `01` | `INC` | Increment the local counter modulo 2^64. |
| `10` | `DEC` | If nonzero, decrement the counter; otherwise leave it at zero. |
| `11` | `HALT` | Enter the halted state until reset or configuration. |

`data` is not interpreted by the v0 arithmetic core. When a reaction emits a new
sticker, the input data is copied unchanged. This makes data available to protocols
without adding hidden arithmetic semantics.

## Persistent cell state

```text
counter       64 bits
halted         1 bit
inc reaction   valid + opcode + target
dec reaction   valid + opcode + target
zero reaction  valid + opcode + target
outbox         valid + 66-bit sticker + target
```

Target width is a fabric parameter and is not part of the 66-bit machine format.
Configuration is a loading/debug interface, not a fifth opcode.

## Reactions

An accepted `INC` selects the `inc` reaction. An accepted nonzero `DEC` selects the
`dec` reaction. An accepted zero `DEC` selects the `zero` reaction. If the selected
reaction is valid, its opcode and target become the outbox message, with input data
copied into the output sticker. `NOP` and `HALT` never emit a reaction in v0.

This table is the smallest program owned by a Logos. It changes where interaction
continues without changing the four arithmetic commands.

## Ready/valid protocol

Inbox and outbox use lossless ready/valid handshakes:

```text
transfer = valid && ready at the rising clock edge
```

- The sender holds `valid`, opcode, data and target stable until transfer.
- A cell accepts at most one inbox sticker per clock.
- A cell emits at most one outbox sticker per accepted command.
- `inbox_ready` is true when the cell is not halted and its outbox is empty, or its
  existing outbox will be accepted on the same edge.
- Backpressure stalls the cell; messages must not be overwritten or dropped.

## Rising-edge order

Priority is exact:

1. `reset`: clear counter, halted and outbox; clear reactions.
2. `configure`: replace counter and reactions; clear halted and outbox.
3. Normal step:
   - retire the old outbox if `outbox_valid && outbox_ready`;
   - if `inbox_valid && inbox_ready`, execute its opcode against the old counter;
   - install the selected reaction as the new outbox, if valid.

A consumed outbox and a newly produced outbox may occur on the same edge.

## Required invariants

- `NOP` changes no persistent state except retirement of an older outbox.
- `INC` wraps from `0xffffffffffffffff` to zero.
- Zero `DEC` remains zero and selects only the zero reaction.
- Nonzero `DEC` subtracts exactly one and selects only the dec reaction.
- `HALT` changes only `halted` and produces no message.
- A stalled outbox remains bit-for-bit stable.
- No accepted sticker is silently lost.
- Implementations must match the reference VM after every rising edge.

## Deliberately outside v0

Routing arbitration, queues deeper than one sticker, broadcast, screen scanning,
fonts, economics, allocation and distributed discovery are fabric or protocol layers.
They must not be smuggled into the semantics of `INC` or `DEC`.
