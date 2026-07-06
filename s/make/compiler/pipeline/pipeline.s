use core

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
