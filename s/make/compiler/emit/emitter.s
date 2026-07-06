use core

EmitterIn = Box {
    checked = none
    path = ""
    format = "v0"
}

EmitterOut = Box {
    bytecode = []
    path = ""
    format = "v0"
}

EmitterContract = Box {
    input = EmitterIn {}
    output = EmitterOut {}
}

skill s_compiler_emitter_contract() {
    out EmitterContract {}
}

skill s_compiler_emitter_stub(in) {
    out EmitterOut {
        bytecode = []
        path = in.path
        format = in.format
    }
}
