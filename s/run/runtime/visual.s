use core

VisualIn = Box {
    event = ""
    subject = ""
    args = []
    state = none
}

VisualOut = Box {
    trace = ""
    state = none
    handled = no
}

VisualContract = Box {
    input = VisualIn {}
    output = VisualOut {}
}

skill s_runtime_visual_contract() {
    out VisualContract {}
}

skill s_runtime_visual_stub(in) {
    out VisualOut {
        trace = ""
        state = in.state
        handled = no
    }
}
