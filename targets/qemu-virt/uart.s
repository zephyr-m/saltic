UART_ADDRESS = [4096, 0]
UART_DATA = 0
UART_STATUS = 5
UART_READY = 32

skill uart_put(device, byte) {
    @status = core.mem.load8(device, UART_STATUS)
    (status < UART_READY) {
        uart_put(device, byte)
        out none
    }

    core.mem.store8(device, UART_DATA, byte)
    out none
}

skill uart_write(text) {
    @device = UART_ADDRESS
    @count = core.str.len(text)
    @index = 0
    drum (count) {
        uart_put(device, core.str.byte(text, index))
        index = index + 1
    }
    out none
}

skill uart_line(text) {
    uart_write(text)
    uart_put(UART_ADDRESS, 10)
    out none
}
