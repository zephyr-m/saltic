use core

TokenIn = Box {
    source = ""
    path = ""
    mode = "scan"
}

TokenOut = Box {
    tokens = []
    source = ""
    path = ""
}

TokenContract = Box {
    input = TokenIn {}
    output = TokenOut {}
}

skill s_compiler_token_contract() {
    out TokenContract {}
}

skill s_compiler_token_stub(in) {
    out TokenOut {
        tokens = []
        source = in.source
        path = in.path
    }
}
