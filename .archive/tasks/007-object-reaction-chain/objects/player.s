PlayerState = enum {
    IDLE,
    MOVED,
    LOCKED,
}

EventKind = enum {
    MOVE,
    LOCK,
}

Point = Box {
    x = 0
    y = 0
}

Player = Box {
    name = "PLAYER"
    state = PlayerState.IDLE
    position = Point {}
}

Event = Box {
    kind = EventKind.MOVE
    dx = 0
    dy = 0
}

skill move_player(player, event) {
    out Player {
        name = player.name
        state = PlayerState.MOVED
        position = Point {
            x = player.position.x + event.dx
            y = player.position.y + event.dy
        }
    }
}

skill lock_player(player) {
    out Player {
        name = player.name
        state = PlayerState.LOCKED
        position = player.position
    }
}

skill react(player, event) {
    (player.state == PlayerState.LOCKED) {
        out player
    }
    (event.kind == EventKind.LOCK) {
        out lock_player(player)
    }
    (event.kind == EventKind.MOVE) {
        out move_player(player, event)
    }
    out player
}
