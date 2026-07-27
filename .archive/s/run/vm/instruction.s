use core

InstrIn = Box {
    op = ""
    target = ""
    argc = 0
    call_kind = ""
}

InstrOut = Box {
    op = ""
    target = ""
    argc = 0
    call_kind = ""
}

InstrContract = Box {
    input = InstrIn {}
    output = InstrOut {}
}

skill s_vm_instruction_contract() {
    out InstrContract {}
}

skill s_vm_instruction_stub(in) {
    out InstrOut {
        op = in.op
        target = in.target
        argc = in.argc
        call_kind = in.call_kind
    }
}
