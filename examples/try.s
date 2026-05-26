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

skill main() {
    @x = 10
    @y = add(x, 5)

    @safe = divide(y, 3) rescue |err| {
        std.io.println("division failed")
        0
    }

    @status = Status.OK

    (status) {
        .OK => std.io.println("ok"),
        .ERROR => std.io.println("error"),
        .DONE => std.io.println("done"),
    }

    drum (MaxRetries) {
        std.io.println("tick")
    }

    out none
}
