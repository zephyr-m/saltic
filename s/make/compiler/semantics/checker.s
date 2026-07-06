use core

CheckerIn = Box {
    ast = none
    path = ""
    scope = none
}

CheckerOut = Box {
    checked = none
    diagnostics = []
    path = ""
}

CheckerContract = Box {
    input = CheckerIn {}
    output = CheckerOut {}
}

skill s_compiler_checker_contract() {
    out CheckerContract {}
}

skill s_compiler_checker_stub(in) {
    out CheckerOut {
        checked = in.ast
        diagnostics = []
        path = in.path
    }
}
