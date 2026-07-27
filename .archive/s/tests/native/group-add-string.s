program() {
    @items = [7]
    @next = core.group.add(items, "sweet")
    @picked = core.group.item(next, 1)
    out core.io.show(picked)
}
