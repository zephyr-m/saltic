use core

ExplainerIn = Box {
    source = ""
    path = ""
    mode = "explain"
}

ExplainerOut = Box {
    text = ""
    diagnostics = []
    path = ""
}

ExplainerContract = Box {
    input = ExplainerIn {}
    output = ExplainerOut {}
}

skill s_tooling_explainer_contract() {
    out ExplainerContract {}
}

skill s_tooling_explainer_stub(in) {
    out ExplainerOut {
        text = ""
        diagnostics = []
        path = in.path
    }
}
