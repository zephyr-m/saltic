program() {
    @items = [7, "sweet", [4, 9], none]
    @nested = core.group.item(items, 2)
    out core.group.count(nested)
}
