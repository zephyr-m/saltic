use core

RunIn = Box {
    source = ""
    entry = ""
    args = []
    state = none
}

RunOut = Box {
    value = none
    state = none
    diagnostics = []
}

RunContract = Box {
    input = RunIn {}
    output = RunOut {}
}

skill s_runtime_runtime_contract() {
    out RunContract {}
}

skill s_runtime_runtime_stub(in) {
    out RunOut {
        value = in.state
        state = in.state
        diagnostics = []
    }
}
