skill core_group_empty() {
    out []
}

skill core_group_add(group, value) {
    out core.group.append(group, value)
}

skill core_group_size(group) {
    out core.group.count(group)
}

skill core_group_item(group, index) {
    out core.group.at(group, index)
}

skill core_group_replace(group, index, value) {
    @result = []
    @cursor = 0
    @count = core.group.count(group)
    drum (count) {
        (cursor < count) {
            (cursor == index) {
                result = core.group.add(result, value)
            }
            (cursor < index) {
                result = core.group.add(result, core.group.at(group, cursor))
            }
            (cursor > index) {
                result = core.group.add(result, core.group.at(group, cursor))
            }
            cursor = cursor + 1
        }
    }
    out result
}
