Token = Box {
    kind = ""
    line = 0
}

skill keep(token) {
    out token
}

program() {
    @token = Token {
        kind = "NAME"
        line = 7
    }
    @same = keep(token)
    out core.io.show(same.kind)
}
