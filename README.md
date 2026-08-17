# Saltic

```s
use core

AppName = "Saltic"

State = enum {
    READY,
    ACTIVE,
    FAILED,
}

Point = Box {
    x = 0
    y = 0
}

Actor = Box {
    name = "agent"
    state = State.READY
    energy = 100
    position = Point {}
}

skill move(point, dx, dy) {
    out Point {
        x = point.x + dx
        y = point.y + dy
    }
}

skill spend(actor, cost) {
    (cost > actor.energy) {
        out error.NotEnoughEnergy
    }

    out Actor {
        name = actor.name
        state = State.ACTIVE
        energy = actor.energy - cost
        position = move(actor.position, 1, 0)
    }
}

skill show(actor) {
    (actor.state) {
        .READY => core.io.show(actor.name, " is ready"),
        .ACTIVE => core.io.show(actor.name, " is active"),
        .FAILED => core.io.show(actor.name, " needs rescue"),
    }

    core.io.show("energy: ", actor.energy)
    core.io.show("position: ", actor.position.x, ",", actor.position.y)
    out none
}

program() {
    @actor = Actor {
        name = "pip"
        energy = 42
        position = Point { x = 2 y = 3 }
    }

    @costs = [5, 7, 11]
    @index = 0

    drum (core.group.count(costs)) {
        @cost = core.group.at(costs, index)
        actor = spend(actor, cost) rescue |err| {
            core.io.show("failed: ", err)
            actor
        }
        index = index + 1
    }

    show(actor)
    out none
}
```
