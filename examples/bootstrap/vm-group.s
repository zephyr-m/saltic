use std

program() {
    @items = [1, 2, 3]
    @index = 0
    @sum = 0

    drum (std.group.count(items)) {
        @item = std.group.at(items, index)
        sum = sum + item
        index = index + 1
    }

    std.io.println("sum=", sum)
    out sum
}
