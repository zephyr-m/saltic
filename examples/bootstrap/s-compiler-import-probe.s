use s.make.compiler.compiler
use s.make.compiler.check_only

program() {
    @source = "program() { @answer = 7 out answer }"
    @compiled = compiler_compile(source, "compiled.s")
    @direct = compiler_check_only(source, "direct.s")
    core.io.println("compiled=", core.group.count(compiled.diagnostics))
    core.io.println("check_only=", core.group.count(direct.diagnostics))
    out none
}
