use core

AppName = "S"
MaxRetries = 3

RunState = enum {
    READY,
    ACTIVE,
    FAILED,
}

ObjectKind = enum {
    AGENT,
    GATE,
    CRYSTAL,
}

Point = Box {
    x = 0
    y = 0
}

Actor = Box {
    name = "agent"
    kind = ObjectKind.AGENT
    state = RunState.READY
    energy = 100
    position = Point {}
}

Event = Box {
    name = "boot"
    cost = 0
}

skill move(point, dx, dy) {
    out Point {
        x = point.x + dx
        y = point.y + dy
    }
}

skill charge_after(actor, event) {
    (event.cost > actor.energy) {
        out error.NotEnoughEnergy
    }

    out actor.energy - event.cost
}

skill react(actor, event) {
    @energy = charge_after(actor, event) rescue |err| {
        core.io.println("reaction failed: ", err)
        0
    }

    @state = RunState.ACTIVE
    (energy == 0) {
        state = RunState.FAILED
    }

    out Actor {
        name = actor.name
        kind = actor.kind
        state = state
        energy = energy
        position = move(actor.position, 1, 0)
    }
}

skill print_actor(actor) {
    core.io.println(actor.name, " energy=", actor.energy)
    core.io.println("kind=", actor.kind)
    core.io.println("state=", actor.state)
    core.io.println("position=", actor.position.x, ",", actor.position.y)
    out none
}

skill explain_state(state) {
    (state) {
        .READY => core.io.println("ready: waiting for first signal"),
        .ACTIVE => core.io.println("active: moving through the world"),
        .FAILED => core.io.println("failed: needs rescue"),
    }
    out none
}

skill observe(actor) {
    visual.sheet("showcase")
    visual.grid(24)
    visual.square_bipyramid(actor.name, 4, 2, "cyan")
    visual.rotate(actor.name, "y", 1)
    visual.present()
    out none
}

skill simulate_world(actor) {
    @object = world.spawn(actor.name)
    world.emit(object, "place", actor.position.x, actor.position.y)
    world.emit(object, "move", 2, 1)
    world.step()
    core.io.println(world.state_text())
    out object
}

program() {
    core.io.println(AppName, " syntax tour")

    @actor = Actor {
        name = "codex"
        energy = 42
        position = Point { x = 2 y = 3 }
    }

    @events = [
        Event { name = "scan" cost = 5 },
        Event { name = "step" cost = 7 },
        Event { name = "build" cost = 11 },
    ]

    @index = 0
    drum (core.group.count(events)) {
        @event = core.group.at(events, index)
        core.io.println("event: ", event.name)
        actor = react(actor, event)
        explain_state(actor.state)
        index = index + 1
    }

    print_actor(actor)
    observe(actor)
    simulate_world(actor)

    out none
}
