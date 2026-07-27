use core

FormatterIn = Box {
    source = ""
    path = ""
    mode = "format"
}

FormatterOut = Box {
    source = ""
    path = ""
    changed = no
}

FormatterContract = Box {
    input = FormatterIn {}
    output = FormatterOut {}
}

skill s_tooling_formatter_contract() {
    out FormatterContract {}
}

skill s_tooling_formatter_stub(in) {
    out FormatterOut {
        source = in.source
        path = in.path
        changed = no
    }
}
