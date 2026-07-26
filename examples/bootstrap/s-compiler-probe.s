use s.make.compiler.compiler

program() {
    @result = compiler_compile("skill add(value) { out value } program() { out add(1) }", "probe.s")
    core.io.println("diagnostics=", core.group.count(result.diagnostics))
    core.io.println("ir=", core.group.count(result.ir))
    core.io.println("ast=", result.ast.kind)
    @broken = compiler_compile("skill add(value) { out value } program() { out ? }", "broken.s")
    @diagnostic = core.group.item(broken.diagnostics, 0)
    core.io.println("broken=", diagnostic.code)
    core.io.println("broken_ir=", core.group.count(broken.ir))
    out none
}
