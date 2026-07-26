use core

skill core_group_replace(group, index, value) {
    @result = []
    @cursor = 0
    @count = core.group.count(group)
    drum (count) {
        (cursor < count) {
            (cursor == index) {
                result = core.group.add(result, value)
            }
            (cursor == index) {
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
