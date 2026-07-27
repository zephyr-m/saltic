Token = Box {
    kind = ""
    value = ""
    line = 1
    col = 1
}

program() {
    @token = Token {
        kind = "NAME"
        value = "candy"
        line = 7
        col = 3
    }
    @items = [7, "sweet", token, [4, 9], none]
    @picked = core.group.item(items, 2)
    out core.io.show(picked.kind)
}
