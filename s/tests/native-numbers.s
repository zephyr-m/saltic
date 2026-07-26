use s.make.compiler.compiler
use s.make.tester

skill expect_llvm(state, source, needle, path) {
    @compiled = compiler_compile(source, path)
    state = tester_expect_in(state, core.group.count(compiled.diagnostics), 0)
    state = tester_expect_in(state, core.str.contains(compiled.llvm, needle), yes)
    out state
}

program() {
    @state = tester_start()
    state = expect_llvm(state, "skill calc(left, right) { out left + right } program() { out calc(7, 5) }", " = add i32 %left, %right", "native-add.s")
    state = expect_llvm(state, "skill calc(left, right) { out left - right } program() { out calc(9, 4) }", " = sub i32 %left, %right", "native-sub.s")
    state = expect_llvm(state, "skill calc(left, right) { out left * right } program() { out calc(6, 7) }", " = mul i32 %left, %right", "native-mul.s")
    state = expect_llvm(state, "skill calc(left, right) { out left / right } program() { out calc(20, 4) }", " = sdiv i32 %left, %right", "native-div.s")
    state = expect_llvm(state, "skill pick(left, right) { (left > right) { out left } out right } program() { out pick(7, 5) }", " = icmp sgt i32 %left, %right", "native-gt.s")
    state = expect_llvm(state, "skill pick(left, right) { (left < right) { out left } out right } program() { out pick(3, 5) }", " = icmp slt i32 %left, %right", "native-lt.s")
    state = expect_llvm(state, "skill pick(left, right) { (left == right) { out left } out right } program() { out pick(5, 5) }", " = icmp eq i32 %left, %right", "native-eq.s")
    tester_summary_state(state)
    out none
}
