ActorBState = enum {
    IDLE,
    ACTIVE,
}

ActorB = Box {
    name = "B"
    state = ActorBState.IDLE
}

skill react_b(actor, leaflet) {
    (leaflet.kind == LeafletKind.PULSE) {
        out ActorB {
            name = actor.name
            state = ActorBState.ACTIVE
        }
    }
    out actor
}
