use s.make.compiler.lexer.scanner
use s.make.compiler.syntax.parser
use s.make.compiler.semantics.checker

program() {
    @scanned = scanner_scan("program() { @value = 42\nout value }", "probe.s")
    @parsed = parser_parse_program(scanned.tokens, "probe.s")
    core.io.println("ast=", parsed.ast.kind)
    core.io.println("body=", core.group.count(parsed.ast.body))
    @checked = checker_check_program(parsed.ast, "probe.s")
    core.io.println("diagnostics=", core.group.count(checked.diagnostics))
    out none
}
