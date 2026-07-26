Point = Box { x = 0, y = 0 }

skill make_point(x, y) {
    out Point { x = x, y = y }
}

program() {
    @point = make_point(7, 5)
    out point.x
}
