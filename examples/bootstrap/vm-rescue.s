use core

skill safe_div(a, b) {
    out a / b rescue |err| {
        0
    }
}

program() {
    @value = safe_div(10, 0)
    core.io.println("value=", value)
    out value
}
