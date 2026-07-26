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

skill scan_chars(source) {
    @tokens = []
    @index = 0
    @length = core.str.len(source)
    drum (length) {
        @ch = core.str.at(source, index)
        @token = token_make("CHAR", ch, 1, index)
        @next = core.group.add(tokens, token)
        tokens = next
        index = index + 1
    }
    out tokens
}

skill pick(tokens, index) {
    @token = core.group.item(tokens, index)
    out token
}

program() {
    @tokens = scan_chars("candy")
    @token = pick(tokens, 4)
    out core.io.show(token.value)
}
