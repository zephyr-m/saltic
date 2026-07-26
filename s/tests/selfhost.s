use s.make.compiler.compiler
use s.make.compiler.pipeline.pipeline
use s.make.runtime.ir
use s.make.tester

program() {
    @state = tester_start()

    @compiled = compiler_compile("program() { out 7 }", "literal.s")
    state = tester_expect_in(state, core.group.count(compiled.diagnostics), 0)
    state = tester_expect_in(state, core.group.count(compiled.ir), 1)
    @ran = runtime_ir_run(compiled.ir)
    state = tester_expect_in(state, ran.value, 7)

    @called = compiler_compile("skill keep(value) { @result = value out result } program() { out keep(7) }", "skill.s")
    state = tester_expect_in(state, core.group.count(called.diagnostics), 0)
    @called_run = runtime_ir_run(called.ir)
    state = tester_expect_in(state, called_run.value, 7)

    @math = compiler_compile("program() { out core.num.add(2, 3) }", "math.s")
    state = tester_expect_in(state, core.group.count(math.diagnostics), 0)
    @math_run = runtime_ir_run(math.ir)
    state = tester_expect_in(state, math_run.value, 5)

    @sub = compiler_compile("program() { out core.num.sub(9, 4) }", "sub.s")
    @sub_run = runtime_ir_run(sub.ir)
    state = tester_expect_in(state, sub_run.value, 5)

    @mul = compiler_compile("program() { out core.num.mul(3, 4) }", "mul.s")
    @mul_run = runtime_ir_run(mul.ir)
    state = tester_expect_in(state, mul_run.value, 12)

    @div = compiler_compile("program() { out core.num.div(12, 3) }", "div.s")
    @div_run = runtime_ir_run(div.ir)
    state = tester_expect_in(state, div_run.value, 4)

    @unknown_name = compiler_compile("program() { out missing }", "unknown-name.s")
    state = tester_expect_in(state, core.group.count(unknown_name.diagnostics), 1)
    state = tester_expect_in(state, core.group.count(unknown_name.ir), 0)
    @unknown_name_diagnostic = core.group.item(unknown_name.diagnostics, 0)
    state = tester_expect_in(state, unknown_name_diagnostic.code, "unknown_name")

    @unknown_call = compiler_compile("program() { out missing(1) }", "unknown-call.s")
    state = tester_expect_in(state, core.group.count(unknown_call.diagnostics), 1)
    @unknown_call_diagnostic = core.group.item(unknown_call.diagnostics, 0)
    state = tester_expect_in(state, unknown_call_diagnostic.code, "unknown_call")

    @wrong_arity = compiler_compile("skill keep(value) { out value } program() { out keep(1, 2) }", "wrong-arity.s")
    state = tester_expect_in(state, core.group.count(wrong_arity.diagnostics), 1)
    @wrong_arity_diagnostic = core.group.item(wrong_arity.diagnostics, 0)
    state = tester_expect_in(state, wrong_arity_diagnostic.code, "wrong_arity")

    @bad_symbol = compiler_compile("program() { out ? }", "bad-symbol.s")
    state = tester_expect_in(state, core.group.count(bad_symbol.diagnostics), 1)
    @bad_symbol_diagnostic = core.group.item(bad_symbol.diagnostics, 0)
    state = tester_expect_in(state, bad_symbol_diagnostic.code, "unknown_symbol")

    @bad_order = compiler_compile("program() { out 1 } skill late(value) { out value }", "bad-order.s")
    state = tester_expect_in(state, core.group.count(bad_order.diagnostics), 1)
    @bad_order_diagnostic = core.group.item(bad_order.diagnostics, 0)
    state = tester_expect_in(state, bad_order_diagnostic.code, "declaration_after_program")

    @pipeline = compiler_pipeline("program() { out 7 }", "pipeline.s")
    state = tester_expect_in(state, core.group.count(pipeline.diagnostics), 0)
    state = tester_expect_in(state, core.group.count(pipeline.bytecode), 1)

    tester_summary_state(state)
    out none
}
