DoorState = enum {
    CLOSED,
    OPEN,
}

DoorEventKind = enum {
    TRY_OPEN,
}

Door = Box {
    name = "DOOR"
    state = DoorState.CLOSED
}

DoorEvent = Box {
    kind = DoorEventKind.TRY_OPEN
    actor_key_state = PlayerState.IDLE
}

skill react_door(door, event) {
    (event.actor_key_state == PlayerState.HAS_KEY) {
        out Door {
            name = door.name
            state = DoorState.OPEN
        }
    }
    out door
}
