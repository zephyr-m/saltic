use core
use s.make.compiler.compiler

program(source_path, llvm_path) {
    @source = core.file.read_text(source_path)
    @compiled = compiler_compile(source, source_path)
    @errors = core.group.count(compiled.diagnostics)
    (errors > 0) {
        core.io.show("saltic: compile failed: ", source_path)
        out none
    }
    core.file.write_text(llvm_path, compiled.llvm)
    core.io.show("saltic: wrote ", llvm_path)
    out none
}
