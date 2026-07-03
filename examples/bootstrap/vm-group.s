use core

program() {
    @items = [1, 2, 3]
    @index = 0
    @sum = 0

    drum (core.group.count(items)) {
        @item = core.group.at(items, index)
        sum = sum + item
        index = index + 1
    }

    core.io.println("sum=", sum)
    out sum
}
