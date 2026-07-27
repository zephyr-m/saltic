use s.make.compiler.lexer.scanner

program() {
    @unknown = scanner_scan("// hidden\n?", "probe.s")
    core.io.println("diagnostics=", core.group.count(unknown.diagnostics))
    out none
}
