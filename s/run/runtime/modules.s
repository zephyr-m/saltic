use core

ModulesIn = Box {
    path = ""
    module = ""
    imports = []
}

ModulesOut = Box {
    module = none
    loaded = no
    imports = []
}

ModulesContract = Box {
    input = ModulesIn {}
    output = ModulesOut {}
}

skill s_runtime_modules_contract() {
    out ModulesContract {}
}

skill s_runtime_modules_stub(in) {
    out ModulesOut {
        module = none
        loaded = no
        imports = in.imports
    }
}
