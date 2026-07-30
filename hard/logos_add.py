"""Addition executed by a lossless fabric of unmodified Logos v0 cells.

The protocol compacts a unary interaction net into two counters:

    left --DEC(nonzero)--> INC accumulator --INC--> DEC left
         --DEC(zero)----> HALT accumulator

Every arrow is a real 66-bit Logos sticker.  Target addresses belong to the
fabric, exactly as specified by LOGOS_SPEC.md.  No Python arithmetic is used to
produce the result; Python only clocks cells and routes their held outboxes.
"""

from dataclasses import dataclass

from logos_vm import Configuration, Logos, Message, Opcode, Reaction, Sticker

LEFT = 0
ACCUMULATOR = 1
TRANSACTION = 0xADD


@dataclass(frozen=True)
class Transfer:
    tick: int
    source: str
    target: int
    opcode: Opcode
    left: int
    accumulator: int


class TwoCellFabric:
    """One lossless route per tick; enough to expose every protocol transfer."""

    def __init__(self, cells: list[Logos]) -> None:
        self.cells = cells
        self.tick_count = 0
        self.trace: list[Transfer] = []

    def transfer(self, source: int | None, message: Message) -> None:
        if not 0 <= message.target < len(self.cells):
            raise RuntimeError(f"invalid target {message.target}")
        target = self.cells[message.target]
        sender = self.cells[source] if source is not None else None

        # A blocked target must leave the sender's outbox untouched.
        sender_will_retire = source is not None
        target_outbox_ready = sender_will_retire and source == message.target
        if not target.inbox_ready(target_outbox_ready):
            raise RuntimeError("fabric deadlock: target is not ready")

        self.tick_count += 1
        if source == message.target:
            accepted = target.step(
                inbox=message.sticker,
                outbox_ready=True,
            )
        else:
            if sender is not None:
                sender.step(outbox_ready=True)
            accepted = target.step(inbox=message.sticker)
        if not accepted:
            raise AssertionError("ready target rejected a sticker")

        self.trace.append(
            Transfer(
                self.tick_count,
                "host" if source is None else str(source),
                message.target,
                message.sticker.opcode,
                self.cells[LEFT].counter,
                self.cells[ACCUMULATOR].counter,
            )
        )

    def run(self, seed: Message, limit: int = 100_000) -> None:
        self.transfer(None, seed)
        while not self.cells[ACCUMULATOR].halted:
            ready = [index for index, cell in enumerate(self.cells) if cell.outbox is not None]
            if len(ready) != 1:
                raise RuntimeError(f"protocol expected one outbox, found {len(ready)}")
            source = ready[0]
            message = self.cells[source].outbox
            assert message is not None
            if self.tick_count >= limit:
                raise RuntimeError("protocol transfer limit exceeded")
            self.transfer(source, message)

        if any(cell.outbox is not None for cell in self.cells):
            raise AssertionError("protocol halted with an undelivered sticker")


def calculate(left: int, right: int, verbose: bool = True) -> TwoCellFabric:
    if left < 0 or right < 0:
        raise ValueError("Logos counters are unsigned")

    cells = [Logos(), Logos()]
    cells[LEFT].step(
        configure=Configuration(
            counter=left,
            dec=Reaction(True, Opcode.INC, ACCUMULATOR),
            zero=Reaction(True, Opcode.HALT, ACCUMULATOR),
        )
    )
    cells[ACCUMULATOR].step(
        configure=Configuration(
            counter=right,
            inc=Reaction(True, Opcode.DEC, LEFT),
        )
    )

    fabric = TwoCellFabric(cells)
    fabric.run(Message(LEFT, Sticker(Opcode.DEC, TRANSACTION)))

    expected = (left + right) & ((1 << 64) - 1)
    assert cells[LEFT].counter == 0
    assert cells[ACCUMULATOR].counter == expected
    assert len(fabric.trace) == 2 * left + 2
    assert all(event.opcode in Opcode for event in fabric.trace)
    assert all(
        event.opcode in (Opcode.DEC, Opcode.INC, Opcode.HALT)
        for event in fabric.trace
    )

    if verbose:
        print(f"Logos ADD({left}, {right})")
        print("tick  route   sticker  left  accumulator")
        for event in fabric.trace:
            print(
                f"{event.tick:>4}  {event.source:>4}->{event.target:<1}  "
                f"{event.opcode.name:<7}  {event.left:>4}  {event.accumulator:>11}"
            )
        print(f"result: {cells[ACCUMULATOR].counter}")
    return fabric


def self_test() -> None:
    for left in range(17):
        for right in range(17):
            fabric = calculate(left, right, verbose=False)
            assert fabric.cells[ACCUMULATOR].counter == left + right
    print("ok fixed Logos sticker ADD protocol (289 cases)")


if __name__ == "__main__":
    calculate(5, 3)
    self_test()
