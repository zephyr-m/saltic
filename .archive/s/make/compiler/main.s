use core
use s.make.compiler.pipeline.pipeline

MainCompilerIn = Box {
    source = ""
    path = ""
    mode = "compile"
}

MainCompilerOut = Box {
    ast = none
    checked = none
    bytecode = []
    diagnostics = []
}

MainCompilerContract = Box {
    input = MainCompilerIn {}
    output = MainCompilerOut {}
}

skill s_compiler_main_contract() {
    out MainCompilerContract {}
}

skill s_compiler_main_stub(in) {
    out MainCompilerOut {
        ast = none
        checked = none
        bytecode = []
        diagnostics = []
    }
}

skill compiler_main(source, path) {
    @pipeline = compiler_pipeline(source, path)
    out MainCompilerOut {
        ast = pipeline.ast
        checked = pipeline.checked
        bytecode = pipeline.bytecode
        diagnostics = pipeline.diagnostics
    }
}
