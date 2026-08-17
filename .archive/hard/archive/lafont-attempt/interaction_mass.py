"""First 16-Logos interaction-mass experiment.

Runs one epsilon >< epsilon graph rewrite using only the normative Logos v0 model.
"""

import sys
from dataclasses import dataclass

from logos_vm import Configuration, Logos, Message, Opcode, Reaction, Sticker

MASS = 16
AGENT_FIELDS = 7
FREE_AT = 14
DONE_AT = 15
TRANSACTION = 1


@dataclass(frozen=True)
class EdgeTrace:
    tick: int
    source: int
    target: int
    opcode: Opcode
    changed: int | None
    before: int
    after: int


class Fabric:
    def __init__(self) -> None:
        self.cells = [Logos() for _ in range(MASS)]
        self.tick = 0
        self.trace: list[EdgeTrace] = []

    def configure(self, counters: list[int]) -> None:
        if len(counters) != MASS:
            raise ValueError("configuration must describe exactly 16 Logos")
        for index, (cell, counter) in enumerate(zip(self.cells, counters)):
            if index < FREE_AT:
                if index < FREE_AT - 1:
                    zero = Reaction(True, Opcode.DEC, index + 1)
                else:
                    zero = Reaction(True, Opcode.HALT, DONE_AT)
                config = Configuration(
                    counter=counter,
                    dec=Reaction(True, Opcode.DEC, index),
                    zero=zero,
                )
            else:
                config = Configuration(counter=counter)
            cell.step(configure=config)

    def inject(self, target: int, sticker: Sticker) -> None:
        before = self.cells[target].counter
        accepted = self.cells[target].step(inbox=sticker, outbox_ready=False)
        if not accepted:
            raise RuntimeError("initial sticker was not accepted")
        after = self.cells[target].counter
        self.trace.append(EdgeTrace(0, -1, target, sticker.opcode, target if before != after else None, before, after))

    def step(self) -> None:
        outgoing: list[tuple[int, Message]] = [
            (source, cell.outbox)
            for source, cell in enumerate(self.cells)
            if cell.outbox is not None
        ]
        if len(outgoing) > 1:
            raise RuntimeError("v0 experiment expects one sticker in flight")

        inboxes: dict[int, Sticker] = {}
        retired: set[int] = set()
        routed: list[tuple[int, Message]] = []
        for source, message in outgoing:
            target = self.cells[message.target]
            if target.inbox_ready(outbox_ready=message.target == source):
                inboxes[message.target] = message.sticker
                retired.add(source)
                routed.append((source, message))

        before = [cell.counter for cell in self.cells]
        accepted_at: set[int] = set()
        for index, cell in enumerate(self.cells):
            accepted = cell.step(
                inbox=inboxes.get(index),
                outbox_ready=index in retired,
            )
            if accepted:
                accepted_at.add(index)

        self.tick += 1
        for source, message in routed:
            target = message.target
            if target not in accepted_at:
                raise RuntimeError("routed sticker was not accepted")
            after = self.cells[target].counter
            changed = target if before[target] != after else None
            self.trace.append(
                EdgeTrace(
                    self.tick,
                    source,
                    target,
                    message.sticker.opcode,
                    changed,
                    before[target],
                    after,
                )
            )

    def running(self) -> bool:
        return not self.cells[DONE_AT].halted


def bits(values: list[int]) -> str:
    return " ".join(f"{value:04b}" for value in values)


def run() -> Fabric:
    # TYPE, STATE, PRINCIPAL, LEFT, RIGHT, LOCK, PAYLOAD for A and B.
    counters = [1, 1, 7, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1, 1, 0, 0]
    fabric = Fabric()
    fabric.configure(counters)

    print("Interaction Mass v0 / 16 Logos")
    print("before:", bits([cell.counter for cell in fabric.cells]))
    fabric.inject(0, Sticker(Opcode.DEC, TRANSACTION))

    while fabric.running():
        fabric.step()
        if fabric.tick > 100:
            raise RuntimeError("rewrite did not terminate")

    final = [cell.counter for cell in fabric.cells]
    print("after: ", bits(final))
    print(f"done:   {int(fabric.cells[DONE_AT].halted)}")
    print(f"ticks:  {fabric.tick}")
    print(f"stickers: {len(fabric.trace)}")

    assert final[:14] == [0] * 14
    assert final[FREE_AT] == 0
    assert fabric.cells[DONE_AT].halted
    assert all(item.opcode == Opcode.DEC for item in fabric.trace[:-1])
    assert fabric.trace[-1].opcode == Opcode.HALT
    for item in fabric.trace:
        if item.changed is not None:
            assert item.opcode == Opcode.DEC
            assert item.before > 0 and item.after == item.before - 1
    return fabric


if __name__ == "__main__":
    result = run()
    if "--trace" in sys.argv:
        print("\ntrace:")
        for edge in result.trace:
            source = "IN" if edge.source < 0 else f"L{edge.source:02d}"
            change = "-" if edge.changed is None else f"{edge.before}->{edge.after}"
            print(
                f"t={edge.tick:02d} {source} -> L{edge.target:02d} "
                f"{edge.opcode.name:<4} counter={change}"
            )
    print("ok epsilon >< epsilon -> free + free")
