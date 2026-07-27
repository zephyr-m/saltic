use core

StackIn = Box {
    stack = none
    value = none
    count = 0
}

StackOut = Box {
    stack = none
    value = none
    count = 0
}

StackContract = Box {
    input = StackIn {}
    output = StackOut {}
}

skill s_vm_stack_contract() {
    out StackContract {}
}

skill s_vm_stack_stub(in) {
    out StackOut {
        stack = in.stack
        value = in.value
        count = in.count
    }
}
