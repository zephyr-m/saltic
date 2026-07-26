Token = Box { kind = "", value = "", line = 1, col = 1 }

skill token_make(kind, value, line, col) {
    out Token { kind = kind, value = value, line = line, col = col }
}

skill scan_lex(source) {
    @tokens = []
    @index = 0
    @length = core.str.len(source)
    drum (length) {
        @part = core.str.slice(source, index, length)
        index = index + 1
    }
    out tokens
}

skill pick(tokens, index) {
    @token = core.group.item(tokens, index)
    out token
}

program() {
    @tokens = scan_lex("program candy = 7")
    @token = pick(tokens, 1)
    out core.io.show(token.value)
}
