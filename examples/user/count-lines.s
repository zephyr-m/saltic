use core

program(path) {
    @text = core.file.read_text(path)
    @count = core.str.lines_count(text)
    core.io.println(path, ": ", count, " lines")
    out none
}
