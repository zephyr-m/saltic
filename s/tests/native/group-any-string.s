program() {
    @items = [7, "sweet", [4, 9], none]
    @picked = core.group.item(items, 1)
    out core.io.show(picked)
}
