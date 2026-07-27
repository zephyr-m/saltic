Point = Box { x = 0, y = 0 }

skill move(point, x, y) {
    point.x = x
    point.y = y
    out point
}

skill shift(point, x) {
    point.x = x
    out point
}

program() {
    @point = Point {}
    @moved = move(point, 7, 9)
    @shifted = shift(moved, 12)
    out shifted.x
}
