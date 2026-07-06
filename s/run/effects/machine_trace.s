use core

MachineTraceIn = Box {
    event = ""
    trace = ""
    state = none
}

MachineTraceOut = Box {
    trace = ""
    state = none
    recorded = no
}

MachineTraceContract = Box {
    input = MachineTraceIn {}
    output = MachineTraceOut {}
}

skill s_effects_machine_trace_contract() {
    out MachineTraceContract {}
}

skill s_effects_machine_trace_stub(in) {
    out MachineTraceOut {
        trace = in.trace
        state = in.state
        recorded = no
    }
}
