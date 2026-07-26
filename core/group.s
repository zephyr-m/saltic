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
