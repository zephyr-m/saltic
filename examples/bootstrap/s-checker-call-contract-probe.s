use s.make.compiler.lexer.scanner
use s.make.compiler.syntax.parser
use s.make.compiler.semantics.checker

program() {
    @scanned = scanner_scan("skill add(left, right) { out left } program() { out add(1) out missing(1) }", "probe.s")
    @parsed = parser_parse_module(scanned.tokens, "probe.s")
    @checked = checker_check_program(parsed.ast, "probe.s")
    core.io.println("diagnostics=", core.group.count(checked.diagnostics))
    @first = core.group.item(checked.diagnostics, 0)
    @second = core.group.item(checked.diagnostics, 1)
    core.io.println(first.code)
    core.io.println(second.code)
    out none
}
