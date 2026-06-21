PlayerState = enum {
    IDLE,
    HAS_KEY,
}

PlayerEventKind = enum {
    PICK_KEY,
}

Player = Box {
    name = "PLAYER"
    state = PlayerState.IDLE
}

PlayerEvent = Box {
    kind = PlayerEventKind.PICK_KEY
}

skill react_player(player, event) {
    (event.kind == PlayerEventKind.PICK_KEY) {
        out Player {
            name = player.name
            state = PlayerState.HAS_KEY
        }
    }
    out player
}
