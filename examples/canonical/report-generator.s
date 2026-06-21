Status = enum {
    PASS,
    WARN,
    FAIL,
}

skill classify(text, needle) {
    (host.str.eq(needle, "")) {
        out Status.WARN
    }
    (host.str.contains(text, needle)) {
        out Status.PASS
    }
    out Status.FAIL
}

skill print_status(status) {
    (status) {
        .PASS => host.io.println("status: PASS"),
        .WARN => host.io.println("status: WARN"),
        .FAIL => host.io.println("status: FAIL"),
    }
    out none
}

skill checklist() {
    drum (3) {
        host.io.println("check: pipeline stage")
    }
    out none
}

skill report(path, needle) {
    @text = host.file.read(path)
    @lines = host.str.lines_count(text)
    @status = classify(text, needle)
    host.io.println("file: ", path)
    host.io.println("lines: ", lines)
    host.io.println("needle: ", needle)
    checklist()
    print_status(status)
    out none
}

program(path, needle) {
    @result = report(path, needle) rescue |err| {
        host.io.println("bad: ", err)
        out none
    }
    host.io.println("done")
    out none
}
