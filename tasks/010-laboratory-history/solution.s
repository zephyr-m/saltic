use std

use objects.laboratory

program() {
    @lab = Laboratory {}
    @inputs = [
        Input {
            kind = InputKind.INSERT_KEY
        },
        Input {
            kind = InputKind.TURN_KEY
        },
        Input {
            kind = InputKind.OPEN_DOOR
        },
    ]
    @index = 0
    @moment = 1
    drum (std.group.count(inputs)) {
        @input = std.group.at(inputs, index)
        lab = dispatch(lab, input)
        observe(moment, input, lab)
        index = index + 1
        moment = moment + 1
    }
    out none
}
