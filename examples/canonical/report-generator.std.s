use std

Status = enum {
    PASS,
    WARN,
    FAIL,
}

skill classify(text, needle) {
    (std.str.eq(needle, "")) {
        out Status.WARN
    }
    (std.str.contains(text, needle)) {
        out Status.PASS
    }
    out Status.FAIL
}

skill print_status(status) {
    (status) {
        .PASS => std.io.println("status: PASS"),
        .WARN => std.io.println("status: WARN"),
        .FAIL => std.io.println("status: FAIL"),
    }
    out none
}

skill checklist() {
    drum (3) {
        std.io.println("check: pipeline stage")
    }
    out none
}

skill report(path, needle) {
    @text = std.file.read_text(path)
    @lines = std.str.lines_count(text)
    @status = classify(text, needle)
    std.io.println("file: ", path)
    std.io.println("lines: ", lines)
    std.io.println("needle: ", needle)
    checklist()
    print_status(status)
    out none
}

program(path, needle) {
    @result = report(path, needle) rescue |err| {
        std.io.println("bad: ", err)
        out none
    }
    std.io.println("done")
    out none
}
