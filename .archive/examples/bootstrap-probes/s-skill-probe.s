use s.make.compiler.lexer.scanner
use s.make.compiler.syntax.parser

program() {
    @scanned = scanner_scan("skill add(a, b) { out 1 }", "probe.s")
    @parsed = parser_parse_skill(scanned.tokens, "probe.s")
    core.io.println(parsed.ast.kind)
    core.io.println(parsed.ast.name)
    core.io.println("params=", core.group.count(parsed.ast.params))
    core.io.println("body=", core.group.count(parsed.ast.body))
    out none
}
