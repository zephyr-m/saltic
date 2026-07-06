use core

CoreIn = Box {
    module = "core"
    name = ""
    args = []
}

CoreOut = Box {
    value = none
    handled = no
    module = "core"
}

CoreContract = Box {
    input = CoreIn {}
    output = CoreOut {}
}

skill s_core_contract() {
    out CoreContract {}
}

skill s_core_stub(in) {
    out CoreOut {
        value = none
        handled = no
        module = in.module
    }
}
