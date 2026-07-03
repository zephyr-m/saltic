use core

use actor_a

use actor_b

Fabric = Box {
    actor_a = ActorA {}
    actor_b = ActorB {}
    outbox = Leaflet {}
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
    core.io.println("moment 1")
    core.io.println("actor ", fabric.actor_a.name, " received ", leaflet.kind)
    core.io.println("actor ", fabric.actor_a.name, " sent ", fabric.outbox.kind, " to ", fabric.outbox.to)
    core.io.println("actor ", fabric.actor_a.name, " state ", fabric.actor_a.state)
    out none
}

skill observe_moment_two(fabric) {
    core.io.println("moment 2")
    core.io.println("actor ", fabric.actor_b.name, " received ", fabric.outbox.kind)
    core.io.println("actor ", fabric.actor_b.name, " state ", fabric.actor_b.state)
    out none
}
