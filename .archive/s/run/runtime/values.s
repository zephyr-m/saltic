use core

ValueIn = Box {
    kind = ""
    number = 0
    text = ""
    name = ""
    value = none
}

ValueOut = Box {
    kind = ""
    number = 0
    text = ""
    name = ""
    value = none
}

ValueContract = Box {
    input = ValueIn {}
    output = ValueOut {}
}

skill s_runtime_value_contract() {
    out ValueContract {}
}

skill s_runtime_value_stub(in) {
    out ValueOut {
        kind = in.kind
        number = in.number
        text = in.text
        name = in.name
        value = in.value
    }
}
