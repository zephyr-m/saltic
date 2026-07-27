Point = Box { x = 0, y = 0 }

skill move(point, x, y) {
    point.x = x
    point.y = y
    out point
}

program() {
    @point = Point {}
    @next = move(point, 7, 9)
    out next.y
}
