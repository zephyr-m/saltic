Token = Box {
    kind = ""
    line = 0
}

program() {
    @token = Token {
        kind = "NAME"
        line = 7
    }
    token.kind = "WORD"
    out core.io.show(token.kind)
}
