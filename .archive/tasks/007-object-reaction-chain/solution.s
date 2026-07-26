use core

use objects.player

program() {
    @player = Player {
        position = Point {
            x = 5
            y = 4
        }
    }
    @events = [
        Event {
            kind = EventKind.MOVE
            dx = 1
            dy = 0
        },
        Event {
            kind = EventKind.MOVE
            dx = 0
            dy = 1
        },
        Event {
            kind = EventKind.LOCK
        },
        Event {
            kind = EventKind.MOVE
            dx = 10
            dy = 0
        },
    ]
    @index = 0
    @current = player
    drum (core.group.count(events)) {
        @event = core.group.at(events, index)
        current = react(current, event)
        index = index + 1
    }
    core.io.println(current.name)
    core.io.println(current.state)
    core.io.println(current.position.x, ",", current.position.y)
    out none
}
