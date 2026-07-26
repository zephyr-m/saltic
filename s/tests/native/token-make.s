Token = Box {
    kind = ""
    value = ""
    line = 1
    col = 1
}

skill token_make(kind, value, line, col) {
    out Token {
        kind = kind
        value = value
        line = line
        col = col
    }
}

program() {
    @token = token_make("NAME", "candy", 7, 3)
    out core.io.show(token.value)
}
