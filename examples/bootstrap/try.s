MaxRetries = 3

Status = enum {
    OK,
    ERROR,
    DONE,
}

skill add(a, b) {
    out a + b
}

skill divide(a, b) {
    (b == 0) {
        out error.DivisionByZero
    }
    out a / b
}

program() {
    @x = 10
    @y = add(x, 5)
    @safe = divide(y, 3) rescue |err| {
        host.io.println("division failed")
        0
    }
    @status = Status.OK
    (status) {
        .OK => host.io.println("ok"),
        .ERROR => host.io.println("error"),
        .DONE => host.io.println("done"),
    }
    drum (MaxRetries) {
        host.io.println("tick")
    }
    out none
}
