use core

Point = Box {
    x = 0,
}

program() {
    @point = Point {}
    point.x = 9
    out point.x
}
