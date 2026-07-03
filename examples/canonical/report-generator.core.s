use core

Status = enum {
    PASS,
    WARN,
    FAIL,
}

skill classify(text, needle) {
    (core.str.eq(needle, "")) {
        out Status.WARN
    }
    (core.str.contains(text, needle)) {
        out Status.PASS
    }
    out Status.FAIL
}

skill print_status(status) {
    (status) {
        .PASS => core.io.println("status: PASS"),
        .WARN => core.io.println("status: WARN"),
        .FAIL => core.io.println("status: FAIL"),
    }
    out none
}

skill checklist() {
    drum (3) {
        core.io.println("check: pipeline stage")
    }
    out none
}

skill report(path, needle) {
    @text = core.file.read_text(path)
    @lines = core.str.lines_count(text)
    @status = classify(text, needle)
    core.io.println("file: ", path)
    core.io.println("lines: ", lines)
    core.io.println("needle: ", needle)
    checklist()
    print_status(status)
    out none
}

program(path, needle) {
    @result = report(path, needle) rescue |err| {
        core.io.println("bad: ", err)
        out none
    }
    core.io.println("done")
    out none
}
