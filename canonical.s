use core

AppName = "Saltic"
MaxEnergy = 100
DefaultStep = 2
Tracing = yes
Silent = no

State = enum {
    READY,
    ACTIVE,
    EMPTY,
}

Kind = enum {
    AGENT,
    SIGNAL,
}

Point = Box {
    x = 0
    y = 0
}

Agent = Box {
    name = "agent"
    kind = Kind.AGENT
    state = State.READY
    energy = MaxEnergy
    point = Point {}
}

Signal = Box {
    name = "signal"
    kind = Kind.SIGNAL
    step = DefaultStep
    cost = 0
}

skill move(point, step) {
    out Point {
        x = point.x + step
        y = point.y + 1
    }
}

skill spend(energy, cost) {
    (cost > energy) {
        out error.NotEnoughEnergy
    }

    out energy - cost
}

skill measure(left, right) {
    @sum = left + right
    @difference = left - right
    @product = left * right
    @quotient = product / right

    (quotient == left) {
        out [sum, difference, product, quotient]
    }

    out error.BadMeasure
}

skill react(agent, signal) {
    @energy = spend(agent.energy, signal.cost)
    @state = State.ACTIVE

    (energy < 1) {
        state = State.EMPTY
    }

    out Agent {
        name = agent.name
        kind = agent.kind
        state = state
        energy = energy
        point = move(agent.point, signal.step)
    }
}

skill show_state(state) {
    (state) {
        .READY => core.io.show("state: ready"),
        .ACTIVE => core.io.show("state: active"),
        .EMPTY => core.io.show("state: empty"),
    }

    out none
}

skill run(agent, signals) {
    @current = agent
    @index = 0

    drum (core.group.count(signals)) {
        @signal = core.group.at(signals, index)
        current = react(current, signal) rescue |err| {
            core.io.show("rescue: ", err)
            current
        }
        show_state(current.state)
        index = index + 1
    }

    out current
}

skill report(agent, input_path, output_path) {
    @text = core.file.read(input_path)
    @lines = core.str.line_count(text)
    @summary = core.str.add(agent.name, ":")
    summary = core.str.add(summary, core.num.text(agent.energy))

    core.io.show(AppName)
    core.io.show("input lines: ", lines)
    core.io.show("agent: ", summary)
    core.file.write(output_path, summary)

    out none
}

program(input_path, output_path) {
    @agent = Agent {
        name = "pip"
        energy = 23
        point = Point { x = 2 y = 3 }
    }

    @signals = [
        Signal { name = "scan" step = 1 cost = 5 },
        Signal { name = "move" step = 2 cost = 7 },
        Signal { name = "build" step = 3 cost = 11 },
    ]

    @numbers = measure(8, 2) rescue |err| {
        core.io.show("measure failed: ", err)
        []
    }

    (Tracing == yes) {
        core.io.show("measure count: ", core.group.count(numbers))
    }

    (Silent == no) {
        core.io.show("run: visible")
    }

    agent = run(agent, signals)
    report(agent, input_path, output_path)

    out none
}
