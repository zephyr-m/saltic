use core

VmValueIn = Box {
    kind = ""
    number = 0
    text = ""
    error_name = ""
    enum_name = ""
    variant_name = ""
}

VmValueOut = Box {
    kind = ""
    number = 0
    text = ""
    error_name = ""
    enum_name = ""
    variant_name = ""
}

VmValueContract = Box {
    input = VmValueIn {}
    output = VmValueOut {}
}

skill s_vm_value_contract() {
    out VmValueContract {}
}

skill s_vm_value_stub(in) {
    out VmValueOut {
        kind = in.kind
        number = in.number
        text = in.text
        error_name = in.error_name
        enum_name = in.enum_name
        variant_name = in.variant_name
    }
}
