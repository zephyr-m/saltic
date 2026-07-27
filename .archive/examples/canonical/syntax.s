use core

Candy = "Saltic"

State = enum {
    READY,
    ACTIVE,
    EMPTY,
}

Point = Box {
    x = 0
    y = 0
}

Agent = Box {
    name = "pip"
    state = State.READY
    energy = 100
    point = Point {}
}

Pulse = Box {
    step = 1
    cost = 0
}

skill move(point, step) {
    out Point {
        x = point.x + step
        y = point.y
    }
}

skill spend(energy, cost) {
    (cost > energy) {
        out error.NotEnoughEnergy
    }

    out energy - cost
}

skill apply(agent, pulse) {
    @energy = spend(agent.energy, pulse.cost)
    @state = State.ACTIVE

    (energy == 0) {
        state = State.EMPTY
    }

    out Agent {
        name = agent.name
        state = state
        energy = energy
        point = move(agent.point, pulse.step)
    }
}

skill show(agent) {
    (agent.state) {
        .READY => core.io.show(agent.name, " is ready"),
        .ACTIVE => core.io.show(agent.name, " is active"),
        .EMPTY => core.io.show(agent.name, " needs energy"),
    }

    core.io.show("energy: ", agent.energy)
    core.io.show("point: ", agent.point.x, ",", agent.point.y)
    out none
}

program() {
    @agent = Agent {
        name = "pip"
        energy = 23
        point = Point { x = 2 y = 3 }
    }

    @flow = [
        Pulse { step = 1 cost = 5 },
        Pulse { step = 2 cost = 7 },
        Pulse { step = 3 cost = 11 },
    ]

    @step = 0
    drum (core.group.count(flow)) {
        @pulse = core.group.at(flow, step)
        agent = apply(agent, pulse) rescue |err| {
            core.io.show("stopped: ", err)
            agent
        }
        step = step + 1
    }

    show(agent)
    out none
}
