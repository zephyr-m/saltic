use core
program() {
    @items = [4, 7]
    @next = core.group.add(items, 9)
    out core.group.count(next)
}
