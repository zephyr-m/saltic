PlayerState = enum {
    IDLE,
    MOVED,
    LOCKED,
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

Move = Box {
    dx = 0
    dy = 0
}

skill react(player, move) {
    (player.state == PlayerState.IDLE) {
        out Player {
            name = player.name
            state = PlayerState.MOVED
            position = Point {
                x = player.position.x + move.dx
                y = player.position.y + move.dy
            }
        }
    }
    out player
}
