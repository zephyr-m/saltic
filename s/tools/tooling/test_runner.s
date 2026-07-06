use core

TestRunnerIn = Box {
    files = []
    mode = "raco"
    filter = ""
}

TestRunnerOut = Box {
    passed = no
    output = ""
    diagnostics = []
}

TestRunnerContract = Box {
    input = TestRunnerIn {}
    output = TestRunnerOut {}
}

skill s_tooling_test_runner_contract() {
    out TestRunnerContract {}
}

skill s_tooling_test_runner_stub(in) {
    out TestRunnerOut {
        passed = no
        output = ""
        diagnostics = []
    }
}
