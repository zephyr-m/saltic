use core

ParserIn = Box {
    source = ""
    path = ""
    tokens = []
}

ParserOut = Box {
    ast = none
    diagnostics = []
    path = ""
}

ParserContract = Box {
    input = ParserIn {}
    output = ParserOut {}
}

skill s_compiler_parser_contract() {
    out ParserContract {}
}

skill s_compiler_parser_stub(in) {
    out ParserOut {
        ast = none
        diagnostics = []
        path = in.path
    }
}
