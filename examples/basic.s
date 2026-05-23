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

skill main() {
    @x = 10
    @y = add(x, 20)

    @safe = divide(y, 2) rescue |err| {
        std.io.println("division failed")
        0
    }

    @status = Status.OK

    (status) {
        .OK => std.io.println("ok"),
        .ERROR => std.io.println("error"),
        .PENDING => std.io.println("pending"),
    }

    drum (5) {
        std.io.println("tick")
    }

    out none
}
