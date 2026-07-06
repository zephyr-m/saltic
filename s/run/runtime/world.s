use core

WorldIn = Box {
    event = ""
    subject = ""
    args = []
    state = none
}

WorldOut = Box {
    trace = ""
    state = none
    handled = no
}

WorldContract = Box {
    input = WorldIn {}
    output = WorldOut {}
}

skill s_runtime_world_contract() {
    out WorldContract {}
}

skill s_runtime_world_stub(in) {
    out WorldOut {
        trace = ""
        state = in.state
        handled = no
    }
}
