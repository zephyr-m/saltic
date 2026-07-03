use core

Point = Box {
    x = 0
    y = 0
}

skill make_point(x, y) {
    out Point {
        x = x
        y = y
    }
}

program() {
    @p = make_point(10, 20)
    core.io.println("x=", p.x)
    out p.y
}
