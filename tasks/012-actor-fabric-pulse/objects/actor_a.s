use leaflet

ActorAState = enum {
    IDLE,
    SENT,
}

ActorA = Box {
    name = "A"
    state = ActorAState.IDLE
}

skill react_a(actor, leaflet) {
    (leaflet.kind == LeafletKind.PING) {
        out ActorA {
            name = actor.name
            state = ActorAState.SENT
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
