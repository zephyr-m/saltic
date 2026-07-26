Token = Box {
    kind = ""
    value = ""
}

skill pick(tokens, index) {
    @token = core.group.item(tokens, index)
    out token
}

program() {
    @first = Token { kind = "NAME", value = "candy" }
    @second = Token { kind = "WORD", value = "sweet" }
    @tokens = [first, second]
    @picked = pick(tokens, 1)
    out core.io.show(picked.kind)
}
