use core

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
    core.io.println(next.name)
    core.io.println(next.state)
    core.io.println(next.position.x, ",", next.position.y)
    out none
}
