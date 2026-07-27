use core

Point = Box {
    x = 0,
    y = 0,
}

program() {
    @point = Point {
        y = 5,
        x = 7,
    }
    out point.x
}
