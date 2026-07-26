use s.make.compiler.lexer.scanner
use s.make.compiler.syntax.parser
use s.make.compiler.semantics.checker

program() {
    @scanned = scanner_scan("program() { out core.str.len(text) }", "probe.s")
    @parsed = parser_parse_program(scanned.tokens, "probe.s")
    @checked = checker_check_program(parsed.ast, "probe.s")
    core.io.println("diagnostics=", core.group.count(checked.diagnostics))
    out none
}
