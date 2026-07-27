use core
use s.make.compiler.compiler

PipelineIn = Box {
    source = ""
    path = ""
    mode = "compile"
}

PipelineOut = Box {
    ast = none
    checked = none
    bytecode = []
    diagnostics = []
}

PipelineContract = Box {
    input = PipelineIn {}
    output = PipelineOut {}
}

skill s_compiler_pipeline_contract() {
    out PipelineContract {}
}

skill s_compiler_pipeline_stub(in) {
    out PipelineOut {
        ast = none
        checked = none
        bytecode = []
        diagnostics = []
    }
}

skill compiler_pipeline(source, path) {
    @compiled = compiler_compile(source, path)
    out PipelineOut {
        ast = compiled.ast
        checked = compiled.ast
        bytecode = compiled.ir
        diagnostics = compiled.diagnostics
    }
}
