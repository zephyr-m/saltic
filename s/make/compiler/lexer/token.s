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
    next = 0
}

Token = Box {
    kind = ""
    value = ""
    line = 1
    col = 1
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

skill token_make(kind, value, line, col) {
    out Token {
        kind = kind
        value = value
        line = line
        col = col
    }
}
