use s.make.compiler.compiler
use s.make.tester

program() {
    @state = tester_start()

    @if_compiled = compiler_compile("program() { (yes) { out 1 } }", "if.s")
    state = tester_expect_in(state, core.group.count(if_compiled.diagnostics), 0)
    @if_instruction = core.group.item(if_compiled.ir, 0)
    state = tester_expect_in(state, if_instruction.op, "IF")
    state = tester_expect_in(state, if_instruction.value.op, "YES")
    state = tester_expect_in(state, core.group.count(if_instruction.body), 1)

    @drum_compiled = compiler_compile("program() { drum (2) { out 1 } }", "drum.s")
    state = tester_expect_in(state, core.group.count(drum_compiled.diagnostics), 0)
    @drum_instruction = core.group.item(drum_compiled.ir, 0)
    state = tester_expect_in(state, drum_instruction.op, "DRUM")
    state = tester_expect_in(state, drum_instruction.value.op, "NUMBER")
    state = tester_expect_in(state, core.group.count(drum_instruction.body), 1)

    tester_summary_state(state)
    out none
}
