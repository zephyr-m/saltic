use core

Point = Box {
    x = 0,
    y = 0,
}

program() {
    @point = Point {
        x = 7,
        y = 5,
    }
    out point.x
}
