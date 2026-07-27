use s.make.compiler.lexer.scanner
use s.make.compiler.syntax.parser
use s.make.compiler.semantics.checker

program() {
    @scanned = scanner_scan("skill add(a, b) { out 1 } program() { out add(1, 2) }", "probe.s")
    @parsed = parser_parse_module(scanned.tokens, "probe.s")
    core.io.println(parsed.ast.kind)
    core.io.println(core.group.count(parsed.ast.items))
    core.io.println(core.group.count(parsed.ast.body))
    @checked = checker_check_program(parsed.ast, "probe.s")
    core.io.println(core.group.count(checked.diagnostics))
    out none
}
