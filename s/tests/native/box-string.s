Token = Box {
    kind = ""
    line = 0
}

program() {
    @token = Token {
        kind = "NAME"
        line = 7
    }
    out core.io.show(token.kind)
}
