use core

skill require_marker(text, needle) {
    (core.str.contains(text, needle)) {
        out none
    }
    out error.MissingMarker
}

skill audit(path, needle) {
    @text = core.file.read_text(path)
    @lines = core.str.lines_count(text)
    require_marker(text, needle)
    core.io.println("file: ", path)
    core.io.println("lines: ", lines)
    core.io.println("marker: ", needle)
    out none
}

program(path, needle) {
    @result = audit(path, needle) rescue |err| {
        core.io.println("bad: ", err)
        out none
    }
    core.io.println("ok")
    out none
}
