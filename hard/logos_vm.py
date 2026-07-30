"""Independent executable reference model for Logos v0.

The normative behavior is documented in LOGOS_SPEC.md. This module intentionally
does not share implementation code with the SystemVerilog or browser models.
"""

import csv
from dataclasses import dataclass, field
from enum import IntEnum
from pathlib import Path
from typing import Optional

MASK64 = (1 << 64) - 1


class Opcode(IntEnum):
    NOP = 0b00
    INC = 0b01
    DEC = 0b10
    HALT = 0b11


@dataclass(frozen=True)
class Sticker:
    opcode: Opcode
    data: int = 0

    def __post_init__(self) -> None:
        if not 0 <= self.data <= MASK64:
            raise ValueError("sticker data must fit in 64 bits")

    def bits(self) -> int:
        return (int(self.opcode) << 64) | self.data


@dataclass(frozen=True)
class Reaction:
    valid: bool = False
    opcode: Opcode = Opcode.NOP
    target: int = 0


@dataclass(frozen=True)
class Message:
    target: int
    sticker: Sticker


@dataclass(frozen=True)
class Configuration:
    counter: int = 0
    inc: Reaction = field(default_factory=Reaction)
    dec: Reaction = field(default_factory=Reaction)
    zero: Reaction = field(default_factory=Reaction)


class Logos:
    def __init__(self) -> None:
        self.counter = 0
        self.halted = False
        self.inc = Reaction()
        self.dec = Reaction()
        self.zero = Reaction()
        self.outbox: Optional[Message] = None

    def inbox_ready(self, outbox_ready: bool) -> bool:
        return not self.halted and (self.outbox is None or outbox_ready)

    def step(
        self,
        *,
        reset: bool = False,
        configure: Optional[Configuration] = None,
        inbox: Optional[Sticker] = None,
        outbox_ready: bool = False,
    ) -> bool:
        """Advance one rising edge and return whether inbox was accepted."""
        if reset:
            self.__init__()
            return False

        if configure is not None:
            if not 0 <= configure.counter <= MASK64:
                raise ValueError("counter must fit in 64 bits")
            self.counter = configure.counter
            self.halted = False
            self.inc = configure.inc
            self.dec = configure.dec
            self.zero = configure.zero
            self.outbox = None
            return False

        ready = self.inbox_ready(outbox_ready)
        if self.outbox is not None and outbox_ready:
            self.outbox = None

        if inbox is None or not ready:
            return False

        reaction: Optional[Reaction] = None
        if inbox.opcode == Opcode.INC:
            self.counter = (self.counter + 1) & MASK64
            reaction = self.inc
        elif inbox.opcode == Opcode.DEC:
            if self.counter == 0:
                reaction = self.zero
            else:
                self.counter -= 1
                reaction = self.dec
        elif inbox.opcode == Opcode.HALT:
            self.halted = True

        if reaction is not None and reaction.valid:
            self.outbox = Message(reaction.target, Sticker(reaction.opcode, inbox.data))
        return True


def self_test() -> None:
    cell = Logos()
    config = Configuration(
        counter=1,
        inc=Reaction(True, Opcode.DEC, 9),
        dec=Reaction(True, Opcode.INC, 10),
        zero=Reaction(True, Opcode.HALT, 11),
    )
    cell.step(configure=config)
    trace_path = Path(__file__).with_name("logos-v0.csv")
    with trace_path.open(newline="", encoding="utf-8") as trace_file:
        for edge, row in enumerate(csv.DictReader(trace_file), start=1):
            values = {name: int(value) for name, value in row.items()}
            inbox = Sticker(Opcode(values["opcode"]), values["data"]) if values["in_valid"] else None
            accepted = cell.step(inbox=inbox, outbox_ready=bool(values["out_ready"]))
            assert accepted == bool(values["accepted"]), f"edge {edge}: accepted"
            assert cell.counter == values["counter"], f"edge {edge}: counter"
            assert cell.halted == bool(values["halted"]), f"edge {edge}: halted"
            assert (cell.outbox is not None) == bool(values["out_valid"]), f"edge {edge}: out_valid"
            if cell.outbox is not None:
                assert int(cell.outbox.sticker.opcode) == values["out_opcode"], f"edge {edge}: out_opcode"
                assert cell.outbox.sticker.data == values["out_data"], f"edge {edge}: out_data"
                assert cell.outbox.target == values["out_target"], f"edge {edge}: out_target"

    wrap = Logos()
    wrap.step(configure=Configuration(counter=MASK64))
    wrap.step(inbox=Sticker(Opcode.INC), outbox_ready=True)
    assert wrap.counter == 0
    print("ok logos v0 reference VM")


if __name__ == "__main__":
    self_test()
