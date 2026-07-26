use s.make.compiler.compiler
use s.make.runtime.ir

program() {
    @compiled = compiler_compile("program() { out 7 }", "probe.s")
    @ran = runtime_ir_run(compiled.ir)
    core.io.println("ok=", ran.ok)
    core.io.println("value=", ran.value)
    core.io.println("steps=", ran.steps)
    out none
}
