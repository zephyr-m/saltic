use s.make.compiler.compiler
use s.make.runtime.ir
use s.make.tester

program() {
    @state = tester_start()
    @compiled = compiler_compile("skill shadow(value) { @value = 9 out value } program() { out shadow(7) }", "shadow.s")
    @ran = runtime_ir_run(compiled.ir)
    state = tester_expect_in(state, core.group.count(compiled.diagnostics), 0)
    state = tester_expect_in(state, ran.value, 9)

    @parent = compiler_compile("skill shadow(value) { @value = 9 out value } program() { @outer = 7 @inner = shadow(9) out outer }", "parent.s")
    @parent_run = runtime_ir_run(parent.ir)
    state = tester_expect_in(state, core.group.count(parent.diagnostics), 0)
    state = tester_expect_in(state, parent_run.value, 7)

    tester_summary_state(state)
    out none
}
