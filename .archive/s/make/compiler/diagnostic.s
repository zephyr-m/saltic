use core

Diagnostic = Box {
    code = ""
    message = ""
    path = ""
    line = 0
    col = 0
}

skill compiler_diagnostic(code, message, path, line, col) {
    out Diagnostic {
        code = code
        message = message
        path = path
        line = line
        col = col
    }
}
