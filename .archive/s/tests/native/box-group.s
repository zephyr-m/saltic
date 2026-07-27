Bag = Box {
    items = []
    label = ""
}

skill keep(bag) {
    out bag
}

program() {
    @bag = Bag {
        items = [4, 7]
        label = "candy"
    }
    @same = keep(bag)
    out core.group.item(same.items, 1)
}
