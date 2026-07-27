use s.make.compiler.emit.llvm
use s.make.tester

program() {
    @state = tester_start()
    @quote = llvm_escape_string("\"")
    state = tester_expect_in(state, quote.text, "\\22")
    state = tester_expect_in(state, quote.length, 2)
    @slash = llvm_escape_string("\\")
    state = tester_expect_in(state, slash.text, "\\5C")
    state = tester_expect_in(state, slash.length, 2)
    @line = llvm_escape_string("\n")
    state = tester_expect_in(state, line.text, "\\0A")
    state = tester_expect_in(state, line.length, 2)
    @tab = llvm_escape_string("\t")
    state = tester_expect_in(state, tab.text, "\\09")
    state = tester_expect_in(state, tab.length, 2)
    tester_summary_state(state)
    out none
}
