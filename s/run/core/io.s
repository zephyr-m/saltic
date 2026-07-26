skill core_io_show(value) {
    out host.io.println(value)
}

skill core_io_println(value) {
    out core_io_show(value)
}
