use core

AstIn = Box {
    tokens = []
    path = ""
}

AstOut = Box {
    ast = none
    tokens = []
    path = ""
}

AstContract = Box {
    input = AstIn {}
    output = AstOut {}
}

skill s_compiler_ast_contract() {
    out AstContract {}
}

skill s_compiler_ast_stub(in) {
    out AstOut {
        ast = none
        tokens = in.tokens
        path = in.path
    }
}
