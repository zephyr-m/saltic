use std

ActorState = enum {
    IDLE,
    SENT,
    ACTIVE,
}

LeafletKind = enum {
    NONE,
    PING,
    PULSE,
}

Actor = Box {
    name = "A"
    state = ActorState.IDLE
}

Leaflet = Box {
    kind = LeafletKind.NONE
    from = ""
    to = ""
}

Fabric = Box {
    actor_a = Actor {
        name = "A"
    }
    actor_b = Actor {
        name = "B"
    }
    outbox = Leaflet {}
}

skill react_a(actor, leaflet) {
    (leaflet.kind == LeafletKind.PING) {
        out Actor {
            name = actor.name
            state = ActorState.SENT
        }
    }
    out actor
}

skill react_b(actor, leaflet) {
    (leaflet.kind == LeafletKind.PULSE) {
        out Actor {
            name = actor.name
            state = ActorState.ACTIVE
        }
    }
    out actor
}

skill emit_pulse(actor) {
    out Leaflet {
        kind = LeafletKind.PULSE
        from = actor.name
        to = "B"
    }
}

skill moment_one(fabric, leaflet) {
    @next_a = react_a(fabric.actor_a, leaflet)
    out Fabric {
        actor_a = next_a
        actor_b = fabric.actor_b
        outbox = emit_pulse(next_a)
    }
}

skill moment_two(fabric) {
    @next_b = react_b(fabric.actor_b, fabric.outbox)
    out Fabric {
        actor_a = fabric.actor_a
        actor_b = next_b
        outbox = fabric.outbox
    }
}

skill observe_moment_one(fabric, leaflet) {
    std.io.println("moment 1")
    std.io.println("actor ", fabric.actor_a.name, " received ", leaflet.kind)
    std.io.println("actor ", fabric.actor_a.name, " sent ", fabric.outbox.kind, " to ", fabric.outbox.to)
    std.io.println("actor ", fabric.actor_a.name, " state ", fabric.actor_a.state)
    out none
}

skill observe_moment_two(fabric) {
    std.io.println("moment 2")
    std.io.println("actor ", fabric.actor_b.name, " received ", fabric.outbox.kind)
    std.io.println("actor ", fabric.actor_b.name, " state ", fabric.actor_b.state)
    out none
}
