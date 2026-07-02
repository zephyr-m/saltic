use std

skill add(a, b) {
    out a + b
}

program() {
    @x = add(2, 3)
    std.io.println("x=", x)
    out x
}
