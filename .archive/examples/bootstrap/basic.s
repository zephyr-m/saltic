MaxRetries = 3

AppName = "S Language"

Status = enum {
    OK,
    ERROR,
    PENDING,
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
    @y = add(x, 20)
    @safe = divide(y, 2) rescue |err| {
        host.io.println("division failed")
        0
    }
    @status = Status.OK
    (status) {
        .OK => host.io.println("ok"),
        .ERROR => host.io.println("error"),
        .PENDING => host.io.println("pending"),
    }
    drum (5) {
        host.io.println("tick")
    }
    out none
}
