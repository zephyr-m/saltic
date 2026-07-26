Bag = Box {
    items = [5]
}

program() {
    @bag = Bag {}
    out core.group.item(bag.items, 0)
}
