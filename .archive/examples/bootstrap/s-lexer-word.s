use s.make.compiler.lexer.scanner

program() {
    @tokens = scanner_scan("program(\"hi\" == 42 => out)", "probe.s")
    core.io.println(tokens.tokens)
    out none
}
