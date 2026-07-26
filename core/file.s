skill core_file_read_text(path) {
    out host.file.read(path)
}

skill core_file_write_text(path, text) {
    host.file.write(path, text)
    out none
}
