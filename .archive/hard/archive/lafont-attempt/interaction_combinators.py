"""Canonical interaction-combinator graph reducer.

This is the normative mathematical model for layer 3. It deliberately does not model
the multi-sticker Logos protocol used to execute an atomic rewrite physically.
"""

from dataclasses import dataclass
from enum import Enum
from typing import TypeAlias

Endpoint: TypeAlias = tuple[int, int]


class Kind(Enum):
    GAMMA = "gamma"      # constructor, arity 2
    DELTA = "delta"      # duplicator, arity 2
    EPSILON = "epsilon"  # eraser, arity 0

    @property
    def arity(self) -> int:
        return 0 if self is Kind.EPSILON else 2


@dataclass(frozen=True)
class Agent:
    id: int
    kind: Kind


@dataclass(frozen=True)
class Fragment:
    """A principal net with one root and an ordered interface."""

    root: Endpoint
    auxiliary: tuple[Endpoint, ...]


class Net:
    def __init__(self) -> None:
        self.agents: dict[int, Agent] = {}
        self.wires: dict[Endpoint, Endpoint] = {}
        self.next_id = 0
        self.next_boundary = -1

    def add(self, kind: Kind) -> int:
        agent_id = self.next_id
        self.next_id += 1
        self.agents[agent_id] = Agent(agent_id, kind)
        return agent_id

    def boundary(self) -> Endpoint:
        endpoint = (self.next_boundary, 0)
        self.next_boundary -= 1
        return endpoint

    def endpoint(self, agent: int, port: int) -> Endpoint:
        if agent not in self.agents:
            raise ValueError(f"unknown agent {agent}")
        if not 0 <= port <= self.agents[agent].kind.arity:
            raise ValueError(f"invalid port {agent}:{port}")
        return (agent, port)

    def connect(self, left: Endpoint, right: Endpoint) -> None:
        if left in self.wires or right in self.wires:
            raise ValueError("port is already connected")
        self.wires[left] = right
        self.wires[right] = left

    def disconnect(self, endpoint: Endpoint) -> Endpoint:
        other = self.wires.pop(endpoint)
        del self.wires[other]
        return other

    def plug(self, left: Endpoint, right: Endpoint) -> None:
        """Remove two interface endpoints and join the wires behind them."""
        left_inner = self.disconnect(left)
        right_inner = self.disconnect(right)
        self.connect(left_inner, right_inner)

    def attach(self, port: Endpoint, interface: Endpoint) -> None:
        """Consume one interface endpoint and attach its inner wire to a port."""
        inner = self.disconnect(interface)
        self.connect(port, inner)

    def remove(self, agent_id: int) -> None:
        agent = self.agents[agent_id]
        for port in range(agent.kind.arity + 1):
            endpoint = (agent_id, port)
            if endpoint in self.wires:
                self.disconnect(endpoint)
        del self.agents[agent_id]

    def active_pairs(self) -> list[tuple[int, int]]:
        pairs = []
        for agent_id in sorted(self.agents):
            principal = (agent_id, 0)
            other = self.wires.get(principal)
            if other is not None and other[1] == 0 and other[0] in self.agents and agent_id < other[0]:
                pairs.append((agent_id, other[0]))
        return pairs

    def normalise(self, limit: int = 100_000) -> list[str]:
        rules: list[str] = []
        while pairs := self.active_pairs():
            if len(rules) >= limit:
                raise RuntimeError(f"normalisation exceeded {limit} rewrites")
            rules.append(self.rewrite(*pairs[0]))
        return rules

    def rewrite(self, left_id: int, right_id: int) -> str:
        if self.wires.get((left_id, 0)) != (right_id, 0):
            raise ValueError("agents are not an active pair")
        left = self.agents[left_id]
        right = self.agents[right_id]
        left_external = [self.wires[(left_id, port)] for port in range(1, left.kind.arity + 1)]
        right_external = [self.wires[(right_id, port)] for port in range(1, right.kind.arity + 1)]
        rule = f"{left.kind.value}-{right.kind.value}"

        self.remove(left_id)
        self.remove(right_id)

        if left.kind is right.kind:
            self._annihilate(left.kind, left_external, right_external)
        elif Kind.EPSILON in (left.kind, right.kind):
            external = right_external if left.kind is Kind.EPSILON else left_external
            self._erase(external)
        else:
            if left.kind is Kind.GAMMA:
                gamma_external, delta_external = left_external, right_external
            else:
                gamma_external, delta_external = right_external, left_external
            self._commute(gamma_external, delta_external)

        self.validate()
        return rule

    def _annihilate(self, kind: Kind, left: list[Endpoint], right: list[Endpoint]) -> None:
        if kind is Kind.EPSILON:
            return
        if kind is Kind.GAMMA:
            self.connect(left[0], right[1])
            self.connect(left[1], right[0])
        else:
            self.connect(left[0], right[0])
            self.connect(left[1], right[1])

    def _erase(self, external: list[Endpoint]) -> None:
        for endpoint in external:
            eraser = self.add(Kind.EPSILON)
            self.connect((eraser, 0), endpoint)

    def _commute(self, gamma_external: list[Endpoint], delta_external: list[Endpoint]) -> None:
        # Two deltas face gamma's former auxiliary wires; two gammas face delta's.
        deltas = [self.add(Kind.DELTA) for _ in range(2)]
        gammas = [self.add(Kind.GAMMA) for _ in range(2)]
        for index in range(2):
            self.connect((deltas[index], 0), gamma_external[index])
            self.connect((gammas[index], 0), delta_external[index])
        # The four internal wires form the canonical commutation grid.
        for gamma_index in range(2):
            for delta_index in range(2):
                self.connect(
                    (gammas[gamma_index], delta_index + 1),
                    (deltas[delta_index], gamma_index + 1),
                )

    def validate(self) -> None:
        for endpoint, other in self.wires.items():
            if self.wires.get(other) != endpoint:
                raise AssertionError("wire is not symmetric")
            agent_id, port = endpoint
            if agent_id >= 0:
                if agent_id not in self.agents:
                    raise AssertionError("wire references a removed agent")
                if not 0 <= port <= self.agents[agent_id].kind.arity:
                    raise AssertionError("wire references an invalid port")
        for agent in self.agents.values():
            for port in range(agent.kind.arity + 1):
                if (agent.id, port) not in self.wires:
                    raise AssertionError(f"unconnected port {agent.id}:{port}")


def multiplexor(net: Net, width: int, dual: bool = False) -> Fragment:
    """Lafont's M_n (or M*_n) gamma multiplexor from figure 4.

    This is the recursive comb presentation: M_0 is epsilon, M_1 is a
    wire, and every following layer is one gamma cell.  The dual comb is
    mirrored, including the order of its observable auxiliary ports.
    """
    if width < 0:
        raise ValueError("multiplexor width must be non-negative")

    root = net.boundary()
    if width == 0:
        eraser = net.add(Kind.EPSILON)
        net.connect(root, (eraser, 0))
        return Fragment(root, ())
    if width == 1:
        auxiliary = net.boundary()
        net.connect(root, auxiliary)
        return Fragment(root, (auxiliary,))

    cell = net.add(Kind.GAMMA)
    net.connect(root, (cell, 0))
    child = multiplexor(net, width - 1, dual)
    exposed = net.boundary()
    if dual:
        net.attach((cell, 1), child.root)
        net.connect((cell, 2), exposed)
        auxiliary = (exposed, *child.auxiliary)
    else:
        net.connect((cell, 1), exposed)
        net.attach((cell, 2), child.root)
        auxiliary = (exposed, *child.auxiliary)
    return Fragment(root, auxiliary)


def transpositor(net: Net, width: int) -> Fragment:
    """Lafont's autodual multiplexor T_n delta comb from figure 5."""
    if width < 0:
        raise ValueError("transpositor width must be non-negative")

    root = net.boundary()
    if width == 0:
        eraser = net.add(Kind.EPSILON)
        net.connect(root, (eraser, 0))
        return Fragment(root, ())
    if width == 1:
        auxiliary = net.boundary()
        net.connect(root, auxiliary)
        return Fragment(root, (auxiliary,))

    cell = net.add(Kind.DELTA)
    net.connect(root, (cell, 0))
    exposed = net.boundary()
    child = transpositor(net, width - 1)
    net.connect((cell, 1), exposed)
    net.attach((cell, 2), child.root)
    return Fragment(root, (exposed, *child.auxiliary))


def rectangular_transpositor(net: Net, pairs: int, singles: int) -> Fragment:
    """Lafont's T_{p,q}; self-composition swaps p pairs and keeps q wires.

    Figure 5 constructs it by putting p gamma cells over the first p outputs
    of the autodual T_{p+q}; the remaining q outputs pass through unchanged.
    """
    if pairs < 0 or singles < 0:
        raise ValueError("transpositor dimensions must be non-negative")

    base = transpositor(net, pairs + singles)
    auxiliary: list[Endpoint] = []
    for index in range(pairs):
        cell = net.add(Kind.GAMMA)
        net.attach((cell, 0), base.auxiliary[index])
        left = net.boundary()
        right = net.boundary()
        net.connect((cell, 1), left)
        net.connect((cell, 2), right)
        auxiliary.extend((left, right))
    auxiliary.extend(base.auxiliary[pairs:])
    return Fragment(base.root, tuple(auxiliary))


def menu(net: Net, packages: list[Fragment]) -> Fragment:
    """Lafont menu pi_1 & ... & pi_n for closed principal packages."""
    if any(package.auxiliary for package in packages):
        raise ValueError("menu currently accepts closed principal packages")
    mux = multiplexor(net, len(packages))
    for port, package in zip(mux.auxiliary, packages):
        net.plug(port, package.root)
    return Fragment(mux.root, ())


def selector(net: Net, choices: int, selected: int) -> Fragment:
    """Lafont selector S^i_n: preserve choice i and erase every other one."""
    if not 0 <= selected < choices:
        raise ValueError("selected menu entry is out of range")
    mux = multiplexor(net, choices, dual=True)
    output = net.boundary()
    for index, port in enumerate(mux.auxiliary):
        if index == selected:
            # Replace the mux interface by the selector's sole auxiliary port.
            inner = net.disconnect(port)
            net.connect(inner, output)
        else:
            eraser = net.add(Kind.EPSILON)
            net.attach((eraser, 0), port)
    return Fragment(mux.root, (output,))


def closed_cell_package(net: Net, kind: Kind) -> Fragment:
    """Small closed package used to test menu selection structurally."""
    root = net.boundary()
    cell = net.add(kind)
    net.connect(root, (cell, 0))
    for port in range(1, kind.arity + 1):
        eraser = net.add(Kind.EPSILON)
        net.connect((cell, port), (eraser, 0))
    return Fragment(root, ())


def rule_fixture(left_kind: Kind, right_kind: Kind) -> tuple[Net, int, int, list[Endpoint]]:
    net = Net()
    left = net.add(left_kind)
    right = net.add(right_kind)
    boundaries: list[Endpoint] = []
    next_boundary = -1
    for agent_id, kind in ((left, left_kind), (right, right_kind)):
        for port in range(1, kind.arity + 1):
            boundary = (next_boundary, 0)
            next_boundary -= 1
            boundaries.append(boundary)
            net.connect((agent_id, port), boundary)
    net.connect((left, 0), (right, 0))
    net.validate()
    return net, left, right, boundaries


def self_test() -> None:
    pairs = [
        (Kind.EPSILON, Kind.EPSILON),
        (Kind.EPSILON, Kind.GAMMA),
        (Kind.EPSILON, Kind.DELTA),
        (Kind.GAMMA, Kind.GAMMA),
        (Kind.GAMMA, Kind.DELTA),
        (Kind.DELTA, Kind.DELTA),
    ]
    expected_agents = [0, 2, 2, 0, 4, 0]
    for (left_kind, right_kind), count in zip(pairs, expected_agents):
        net, left, right, boundaries = rule_fixture(left_kind, right_kind)
        assert net.active_pairs() == [(left, right)]
        rule = net.rewrite(left, right)
        assert len(net.agents) == count, rule
        assert not net.active_pairs(), rule
        assert all(boundary in net.wires or left_kind is right_kind is Kind.EPSILON for boundary in boundaries)
        if left_kind is right_kind is Kind.GAMMA:
            assert net.wires[boundaries[0]] == boundaries[3]
            assert net.wires[boundaries[1]] == boundaries[2]
        if left_kind is right_kind is Kind.DELTA:
            assert net.wires[boundaries[0]] == boundaries[2]
            assert net.wires[boundaries[1]] == boundaries[3]
        if left_kind is Kind.GAMMA and right_kind is Kind.DELTA:
            assert all(net.agents[net.wires[boundary][0]].kind is Kind.DELTA for boundary in boundaries[:2])
            assert all(net.agents[net.wires[boundary][0]].kind is Kind.GAMMA for boundary in boundaries[2:])
        print(f"ok {rule:<15} agents={len(net.agents)} wires={len(net.wires) // 2}")

    for width in range(9):
        net = Net()
        normal = multiplexor(net, width)
        dual = multiplexor(net, width, dual=True)
        net.plug(normal.root, dual.root)
        rules = net.normalise()
        assert not net.agents
        for index in range(width):
            assert net.wires[normal.auxiliary[index]] == dual.auxiliary[index]
        net.validate()
        print(f"ok M_{width}-M*_{width:<2} rewrites={len(rules)}")

    for width in range(9):
        net = Net()
        left = transpositor(net, width)
        right = transpositor(net, width)
        net.plug(left.root, right.root)
        rules = net.normalise()
        assert not net.agents
        for index in range(width):
            assert net.wires[left.auxiliary[index]] == right.auxiliary[index]
        net.validate()
        print(f"ok T_{width}-T_{width:<3} rewrites={len(rules)}")

    for pairs in range(5):
        for singles in range(5):
            net = Net()
            left = rectangular_transpositor(net, pairs, singles)
            right = rectangular_transpositor(net, pairs, singles)
            net.plug(left.root, right.root)
            rules = net.normalise()
            assert not net.agents
            for index in range(2 * pairs):
                assert net.wires[left.auxiliary[index]] == right.auxiliary[index ^ 1]
            for index in range(2 * pairs, 2 * pairs + singles):
                assert net.wires[left.auxiliary[index]] == right.auxiliary[index]
            net.validate()
            print(f"ok T_{{{pairs},{singles}}}^2      rewrites={len(rules)}")

    for width in range(9):
        net = Net()
        package = multiplexor(net, width)
        eraser = net.add(Kind.EPSILON)
        eraser_root = net.boundary()
        net.connect(eraser_root, (eraser, 0))
        net.plug(eraser_root, package.root)
        rules = net.normalise()
        assert len(net.agents) == width
        for boundary in package.auxiliary:
            neighbour = net.wires[boundary]
            assert net.agents[neighbour[0]].kind is Kind.EPSILON
        net.validate()
        print(f"ok erase M_{width:<2}     rewrites={len(rules)}")

    package_kinds = [Kind.EPSILON, Kind.GAMMA, Kind.DELTA]
    expected_counts = [1, 3, 3]
    for selected, selected_kind in enumerate(package_kinds):
        net = Net()
        packages = [closed_cell_package(net, kind) for kind in package_kinds]
        choices = menu(net, packages)
        choose = selector(net, len(packages), selected)
        net.plug(choices.root, choose.root)
        rules = net.normalise()
        assert len(net.agents) == expected_counts[selected]
        selected_root = net.wires[choose.auxiliary[0]]
        assert net.agents[selected_root[0]].kind is selected_kind
        assert selected_root[1] == 0
        net.validate()
        print(f"ok menu[3] select {selected}  rewrites={len(rules)}")


if __name__ == "__main__":
    self_test()
