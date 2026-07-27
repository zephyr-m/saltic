use core

InterpreterIn = Box {
    bytecode = []
    functions = []
    boundaries = []
    entry = ""
}

InterpreterOut = Box {
    result = none
    frames = []
    trace = ""
}

InterpreterContract = Box {
    input = InterpreterIn {}
    output = InterpreterOut {}
}

skill s_vm_interpreter_contract() {
    out InterpreterContract {}
}

skill s_vm_interpreter_stub(in) {
    out InterpreterOut {
        result = none
        frames = []
        trace = in.entry
    }
}
