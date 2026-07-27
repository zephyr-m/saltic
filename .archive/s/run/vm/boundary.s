use core

call = Box {
    name = ""
    argc = 0
    args = []
    state = none
}

result = Box {
    value = none
    state = none
    handled = no
    error = none
}

input = Box {
    name = ""
    argc = 0
    args = []
    state = none
}

output = Box {
    value = none
    state = none
    handled = no
}

contract = Box {
    input = input {}
    output = output {}
}

skill s_vm_boundary_contract() {
    out contract {}
}

skill s_vm_boundary_stub(in) {
    out output {
        value = none
        state = in.state
        handled = no
    }
}
