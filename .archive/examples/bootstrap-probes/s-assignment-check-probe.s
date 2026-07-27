use s.make.compiler.lexer.scanner
use s.make.compiler.syntax.parser
use s.make.compiler.semantics.checker

program() {
    @scanned = scanner_scan("program() { @answer = 7 out answer }", "probe.s")
    @parsed = parser_parse_module(scanned.tokens, "probe.s")
    core.io.println("parsed=", parsed.ast.kind)
    core.io.println("body=", core.group.count(parsed.ast.body))
    @checked = checker_check_program(parsed.ast, "probe.s")
    core.io.println("diagnostics=", core.group.count(checked.diagnostics))
    @first = core.group.item(parsed.ast.body, 0)
    @second = core.group.item(parsed.ast.body, 1)
    core.io.println("first=", first.kind, "/", first.name)
    core.io.println("second=", second.kind, "/", second.name)
    out none
}
