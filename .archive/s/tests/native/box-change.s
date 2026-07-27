Point = Box { x = 0 }

skill move(point, x) {
    point.x = x
    out point
}

program() {
    @point = Point {}
    @next = move(point, 9)
    out next.x
}
