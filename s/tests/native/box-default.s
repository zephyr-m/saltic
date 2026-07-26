use core

Point = Box {
    x = 1,
    y = 5,
}

program() {
    @point = Point {
        x = 7,
    }
    out point.y
}
