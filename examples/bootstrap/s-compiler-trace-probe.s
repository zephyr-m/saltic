use s.make.compiler.compiler

program() {
    @source = "program() { @answer = 7 out answer }"
    @traced = compiler_trace_scan(source, "trace.s")
    out none
}
