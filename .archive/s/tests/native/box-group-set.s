Bag = Box {
    items = []
}

program() {
    @bag = Bag {}
    bag.items = [9, 12, 15]
    out core.group.count(bag.items)
}
