Token = Box {
    kind = ""
}

program() {
    @token = Token { kind = "NAME" }
    @items = [7]
    @next = core.group.add(items, token)
    @picked = core.group.item(next, 1)
    out core.io.show(picked.kind)
}
