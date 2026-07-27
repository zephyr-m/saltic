use core

Status = enum {
    OK,
    ERROR,
    PENDING,
}

program() {
    @status = Status.OK

    (status) {
        .OK => core.io.println("status=ok"),
        .ERROR => core.io.println("status=error"),
        .PENDING => core.io.println("status=pending"),
    }

    core.io.println(status)
    out none
}
