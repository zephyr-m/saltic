use core
use s.make.compiler.lexer.scanner
use s.make.compiler.syntax.parser
use s.make.compiler.semantics.checker

skill compiler_check_only(source, path) {
    @scanned = scanner_scan(source, path)
    @parsed = parser_parse_module(scanned.tokens, path)
    out checker_check_program(parsed.ast, path)
}
