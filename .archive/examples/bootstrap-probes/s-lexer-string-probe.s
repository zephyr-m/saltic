use s.make.compiler.lexer.scanner

program() {
    @result = scanner_read_string("\"open", 0, 1, 1)
    @token = core.group.item(result.tokens, 0)
    core.io.println(token.kind)
    out none
}
