Token = Box {
    kind = ""
    value = ""
    line = 0
    col = 0
}

skill rename(token, kind) {
    token.kind = kind
    out token
}

skill keep(token) {
    out token
}

program() {
    @token = Token {
        kind = "NAME"
        value = "candy"
        line = 7
        col = 3
    }
    @renamed = rename(token, "WORD")
    @same = keep(renamed)
    out core.io.show(same.kind)
}
