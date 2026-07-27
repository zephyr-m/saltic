use core

skill add(a, b) {
    out a + b
}

program() {
    @x = add(2, 3)
    core.io.println("x=", x)
    out x
}
