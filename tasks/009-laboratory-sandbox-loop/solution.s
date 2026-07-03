use core

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
    drum (core.group.count(inputs)) {
        @input = core.group.at(inputs, index)
        lab = dispatch(lab, input)
        render(lab)
        index = index + 1
    }
    out none
}
