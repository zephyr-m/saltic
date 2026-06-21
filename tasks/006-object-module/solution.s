use std

use objects.player

program() {
    @player = Player {
        position = Point {
            x = 5
            y = 4
        }
    }
    @move = Move {
        dx = 1
        dy = 0
    }
    @next = react(player, move)
    std.io.println(next.name)
    std.io.println(next.state)
    std.io.println(next.position.x, ",", next.position.y)
    out none
}
