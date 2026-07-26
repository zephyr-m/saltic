use s.make.compiler.compiler
use s.make.compiler.lexer.scanner
use s.make.compiler.syntax.parser
use s.make.compiler.semantics.checker

program() {
    @source = "program() { @answer = 7 out answer }"
    @compiled = compiler_compile(source, "compiled.s")
    core.io.println("compiled=", core.group.count(compiled.diagnostics))
    core.io.println("stages=", compiled.scan_errors, "/", compiled.parse_errors, "/", compiled.check_errors)
    @staged_scanned = compiler_scan(source, "staged.s")
    @staged_parsed = compiler_parse(staged_scanned.tokens, "staged.s")
    @staged_checked = compiler_check(staged_parsed.ast, "staged.s")
    core.io.println("staged=", core.group.count(staged_checked.diagnostics))
    @scanned = scanner_scan(source, "direct.s")
    @parsed = parser_parse_module(scanned.tokens, "direct.s")
    @checked = checker_check_program(parsed.ast, "direct.s")
    core.io.println("direct=", core.group.count(checked.diagnostics))
    out none
}
