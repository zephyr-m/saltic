use core

StepIn = Box {
    frame = none
    instruction = none
    vm_state = none
}

StepOut = Box {
    frame = none
    vm_state = none
    returned = no
    error = none
}

StepContract = Box {
    input = StepIn {}
    output = StepOut {}
}

skill s_vm_step_contract() {
    out StepContract {}
}

skill s_vm_step_stub(in) {
    out StepOut {
        frame = in.frame
        vm_state = in.vm_state
        returned = no
        error = none
    }
}
