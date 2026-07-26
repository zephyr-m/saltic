use s.make.compiler.compiler
use s.make.compiler.emit.emitter

program() {
    @compiled = compiler_compile("skill add(value) { out value } program() { out 1 }", "probe.s")
    @emitted = compiler_emit(compiled.ast)
    core.io.println("diagnostics=", core.group.count(emitted.diagnostics))
    core.io.println("instructions=", core.group.count(emitted.instructions))
    @decl = core.group.item(emitted.instructions, 0)
    @assign = core.group.item(emitted.instructions, 1)
    core.io.println(decl.op, "/", decl.name)
    core.io.println(assign.op, "/", assign.name)
    out none
}
