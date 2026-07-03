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
    @objects = [
        Object {
            name = "PLAYER"
            position = Point {
                x = 5
                y = 4
            }
        },
        Object {
            name = "LIGHT"
            position = Point {
                x = 2
                y = 2
            }
        },
        Object {
            name = "WALL"
            position = Point {
                x = 10
                y = 4
            }
        },
    ]
    core.io.println("frame: ", frame.width, "x", frame.height)
    core.io.println("camera: ", camera.position.x, ",", camera.position.y)
    @index = 0
    drum (core.group.count(objects)) {
        @object = core.group.at(objects, index)
        @object_visibility = visibility(object, camera)
        print_object(object, object_visibility)
        index = index + 1
    }
    out none
}
