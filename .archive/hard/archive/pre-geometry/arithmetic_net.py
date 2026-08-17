"""Small source interaction system for unary addition.

This is the understandable source graph that will later be translated to the fixed
gamma/delta/epsilon interaction-combinator graph.
"""

from dataclasses import dataclass
from enum import Enum
from typing import TypeAlias

Endpoint: TypeAlias = tuple[int, int]
RESULT: Endpoint = (-1, 0)


class Symbol(Enum):
    ZERO = "ZERO"
    S = "S"
    ADD = "ADD"

    @property
    def arity(self) -> int:
        return {Symbol.ZERO: 0, Symbol.S: 1, Symbol.ADD: 2}[self]


@dataclass(frozen=True)
class Agent:
    id: int
    symbol: Symbol


@dataclass(frozen=True)
class Reduction:
    step: int
    rule: str
    agents_before: int
    agents_after: int


class ArithmeticNet:
    def __init__(self) -> None:
        self.agents: dict[int, Agent] = {}
        self.wires: dict[Endpoint, Endpoint] = {}
        self.next_id = 0
        self.trace: list[Reduction] = []

    def add_agent(self, symbol: Symbol) -> int:
        agent_id = self.next_id
        self.next_id += 1
        self.agents[agent_id] = Agent(agent_id, symbol)
        return agent_id

    def connect(self, left: Endpoint, right: Endpoint) -> None:
        if left in self.wires or right in self.wires:
            raise ValueError(f"port already connected: {left} or {right}")
        self.wires[left] = right
        self.wires[right] = left

    def disconnect(self, endpoint: Endpoint) -> Endpoint:
        other = self.wires.pop(endpoint)
        del self.wires[other]
        return other

    def remove(self, agent_id: int) -> None:
        agent = self.agents[agent_id]
        for port in range(agent.symbol.arity + 1):
            endpoint = (agent_id, port)
            if endpoint in self.wires:
                self.disconnect(endpoint)
        del self.agents[agent_id]

    def numeral(self, value: int) -> Endpoint:
        if value < 0:
            raise ValueError("natural number must be non-negative")
        zero = self.add_agent(Symbol.ZERO)
        root = (zero, 0)
        for _ in range(value):
            successor = self.add_agent(Symbol.S)
            self.connect((successor, 1), root)
            root = (successor, 0)
        return root

    def build_add(self, left: int, right: int) -> None:
        left_root = self.numeral(left)
        right_root = self.numeral(right)
        add = self.add_agent(Symbol.ADD)
        self.connect((add, 0), left_root)
        self.connect((add, 1), right_root)
        self.connect((add, 2), RESULT)
        self.validate()

    def active_pair(self) -> tuple[int, int] | None:
        for agent_id in sorted(self.agents):
            other = self.wires.get((agent_id, 0))
            if other is None or other[1] != 0 or other[0] not in self.agents:
                continue
            if self.agents[agent_id].symbol is Symbol.ADD:
                return agent_id, other[0]
        return None

    def reduce_one(self) -> bool:
        pair = self.active_pair()
        if pair is None:
            return False
        add_id, value_id = pair
        value = self.agents[value_id]
        if value.symbol not in (Symbol.S, Symbol.ZERO):
            raise RuntimeError(f"ADD cannot interact with {value.symbol.value}")

        second = self.wires[(add_id, 1)]
        result = self.wires[(add_id, 2)]
        tail = self.wires[(value_id, 1)] if value.symbol is Symbol.S else None
        before = len(self.agents)
        self.remove(add_id)
        self.remove(value_id)

        if value.symbol is Symbol.ZERO:
            self.connect(second, result)
            rule = "ADD×ZERO"
        else:
            recursive_add = self.add_agent(Symbol.ADD)
            successor = self.add_agent(Symbol.S)
            self.connect((recursive_add, 0), tail)
            self.connect((recursive_add, 1), second)
            self.connect((recursive_add, 2), (successor, 1))
            self.connect((successor, 0), result)
            rule = "ADD×S"

        self.validate()
        self.trace.append(Reduction(len(self.trace) + 1, rule, before, len(self.agents)))
        return True

    def normalise(self, limit: int = 10000) -> None:
        while self.reduce_one():
            if len(self.trace) >= limit:
                raise RuntimeError("reduction limit reached")

    def result(self) -> int:
        if RESULT not in self.wires:
            raise RuntimeError("result boundary is disconnected")
        endpoint = self.wires[RESULT]
        value = 0
        visited: set[int] = set()
        while True:
            agent_id, port = endpoint
            if agent_id in visited or agent_id not in self.agents or port != 0:
                raise RuntimeError("result is not a unary numeral")
            visited.add(agent_id)
            symbol = self.agents[agent_id].symbol
            if symbol is Symbol.ZERO:
                return value
            if symbol is not Symbol.S:
                raise RuntimeError("result is not in normal form")
            value += 1
            endpoint = self.wires[(agent_id, 1)]

    def validate(self) -> None:
        for endpoint, other in self.wires.items():
            if self.wires.get(other) != endpoint:
                raise AssertionError("asymmetric wire")
            agent_id, port = endpoint
            if agent_id >= 0:
                if agent_id not in self.agents:
                    raise AssertionError("wire references removed agent")
                if not 0 <= port <= self.agents[agent_id].symbol.arity:
                    raise AssertionError("wire references invalid port")
        for agent in self.agents.values():
            for port in range(agent.symbol.arity + 1):
                if (agent.id, port) not in self.wires:
                    raise AssertionError(f"unconnected port {agent.id}:{port}")


def calculate(left: int, right: int, verbose: bool = True) -> ArithmeticNet:
    net = ArithmeticNet()
    net.build_add(left, right)
    if verbose:
        print(f"input:  ADD({left}, {right})")
    net.normalise()
    result = net.result()
    if verbose:
        for reduction in net.trace:
            print(
                f"step {reduction.step:02d}: {reduction.rule:<8} "
                f"agents {reduction.agents_before}->{reduction.agents_after}"
            )
        print(f"unary:  {'S(' * result}ZERO{')' * result}")
        print(f"binary: {result:b}")
        print(f"result: {result}")
    assert result == left + right
    return net


def self_test() -> None:
    for left, right in ((0, 0), (0, 3), (5, 0), (5, 3), (12, 7)):
        net = calculate(left, right, verbose=False)
        assert len(net.trace) == left + 1
    print("ok unary interaction-net addition")


if __name__ == "__main__":
    calculate(5, 3)
    self_test()
