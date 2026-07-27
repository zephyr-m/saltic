use core

BytecodeDataIn = Box {
    bytecode = []
    path = ""
    format = "v0"
}

BytecodeDataOut = Box {
    artifact = none
    bytecode = []
    unit = none
    format = "v0"
}

BytecodeDataContract = Box {
    input = BytecodeDataIn {}
    output = BytecodeDataOut {}
}

skill s_vm_bytecode_data_contract() {
    out BytecodeDataContract {}
}

skill s_vm_bytecode_data_stub(in) {
    out BytecodeDataOut {
        artifact = in.bytecode
        bytecode = in.bytecode
        unit = none
        format = in.format
    }
}
