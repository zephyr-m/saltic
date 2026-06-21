skill require_marker(text, needle) {
    (host.str.contains(text, needle)) {
        out none
    }
    out error.MissingMarker
}

skill audit(path, needle) {
    @text = host.file.read(path)
    @lines = host.str.lines_count(text)
    require_marker(text, needle)
    host.io.println("file: ", path)
    host.io.println("lines: ", lines)
    host.io.println("marker: ", needle)
    out none
}

program(path, needle) {
    @result = audit(path, needle) rescue |err| {
        host.io.println("bad: ", err)
        out none
    }
    host.io.println("ok")
    out none
}
