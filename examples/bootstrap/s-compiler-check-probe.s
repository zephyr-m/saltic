use s.make.compiler.compiler

program() {
    @result = compiler_compile("program() { out missing }", "probe.s")
    @diagnostic = core.group.item(result.diagnostics, 0)
    core.io.println("diagnostics=", core.group.count(result.diagnostics))
    core.io.println("code=", diagnostic.code)
    core.io.println("ir=", core.group.count(result.ir))
    out none
}
