use core

CallIn = Box {
    target = ""
    argc = 0
    args = []
    call_kind = ""
    frame = none
}

CallOut = Box {
    value = none
    frame = none
    handled = no
}

CallContract = Box {
    input = CallIn {}
    output = CallOut {}
}

skill s_runtime_call_contract() {
    out CallContract {}
}

skill s_runtime_call_stub(in) {
    out CallOut {
        value = none
        frame = in.frame
        handled = no
    }
}
