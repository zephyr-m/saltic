use std

program(path) {
    @text = std.file.read_text(path)
    @count = std.str.lines_count(text)
    std.io.println(path, ": ", count, " lines")
    out none
}
