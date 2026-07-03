use core

Visibility = enum {
    VISIBLE,
    HIDDEN,
}

Point = Box {
    x = 0
    y = 0
}

Frame = Box {
    width = 0
    height = 0
}

Camera = Box {
    position = Point {}
    radius = 0
}

Object = Box {
    name = ""
    position = Point {}
}

skill visibility(object, camera) {
    @dx = object.position.x - camera.position.x
    @dy = object.position.y - camera.position.y
    @distance = dx * dx + dy * dy
    @limit = camera.radius * camera.radius
    (distance < limit) {
        out Visibility.VISIBLE
    }
    out Visibility.HIDDEN
}

skill print_object(object, visibility) {
    (visibility) {
        .VISIBLE => core.io.println(object.name, " visible at ", object.position.x, ",", object.position.y),
        .HIDDEN => core.io.println(object.name, " hidden at ", object.position.x, ",", object.position.y),
    }
    out none
}

program() {
    @frame = Frame {
        width = 20
        height = 10
    }
    @camera = Camera {
        position = Point {
            x = 0
            y = 0
        }
        radius = 8
    }
    @player = Object {
        name = "PLAYER"
        position = Point {
            x = 5
            y = 4
        }
    }
    @light = Object {
        name = "LIGHT"
        position = Point {
            x = 2
            y = 2
        }
    }
    @wall = Object {
        name = "WALL"
        position = Point {
            x = 10
            y = 4
        }
    }
    @player_visibility = visibility(player, camera)
    @light_visibility = visibility(light, camera)
    @wall_visibility = visibility(wall, camera)
    core.io.println("frame: ", frame.width, "x", frame.height)
    core.io.println("camera: ", camera.position.x, ",", camera.position.y)
    print_object(player, player_visibility)
    print_object(light, light_visibility)
    print_object(wall, wall_visibility)
    out none
}
