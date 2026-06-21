use std

skill require_marker(text, needle) {
    (std.str.contains(text, needle)) {
        out none
    }
    out error.MissingMarker
}

skill audit(path, needle) {
    @text = std.file.read_text(path)
    @lines = std.str.lines_count(text)
    require_marker(text, needle)
    std.io.println("file: ", path)
    std.io.println("lines: ", lines)
    std.io.println("marker: ", needle)
    out none
}

program(path, needle) {
    @result = audit(path, needle) rescue |err| {
        std.io.println("bad: ", err)
        out none
    }
    std.io.println("ok")
    out none
}
