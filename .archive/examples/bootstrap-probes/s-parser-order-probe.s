use s.make.compiler.lexer.scanner
use s.make.compiler.syntax.parser

program() {
    @scanned = scanner_scan("program() { out 1 } skill late(value) { out value }", "probe.s")
    @parsed = parser_parse_module(scanned.tokens, "probe.s")
    core.io.println("diagnostics=", core.group.count(parsed.diagnostics))
    @diagnostic = core.group.item(parsed.diagnostics, 0)
    core.io.println(diagnostic.code)
    out none
}
