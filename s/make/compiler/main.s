use core

CompilerIn = Box {
    source = ""
    path = ""
    mode = "compile"
}

CompilerOut = Box {
    ast = none
    checked = none
    bytecode = []
    diagnostics = []
}

CompilerContract = Box {
    input = CompilerIn {}
    output = CompilerOut {}
}

skill s_compiler_main_contract() {
    out CompilerContract {}
}

skill s_compiler_main_stub(in) {
    out CompilerOut {
        ast = none
        checked = none
        bytecode = []
        diagnostics = []
    }
}
