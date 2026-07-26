use s.make.compiler.compiler
use s.make.tester

program() {
    @state = tester_start()
    @result = compiler_compile("program() { out missing }", "diagnostics.s")
    @diagnostic = core.group.item(result.diagnostics, 0)

    state = tester_expect_in(state, diagnostic.code, "unknown_name")
    state = tester_expect_in(state, diagnostic.message, "unknown name")
    state = tester_expect_in(state, diagnostic.path, "diagnostics.s")
    state = tester_expect_in(state, diagnostic.line, 1)
    state = tester_expect_in(state, diagnostic.col, 17)

    tester_summary_state(state)
    out none
}
