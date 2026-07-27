use core

TaskRunnerIn = Box {
    task = ""
    files = []
    mode = "task"
}

TaskRunnerOut = Box {
    passed = no
    output = ""
    diagnostics = []
}

TaskRunnerContract = Box {
    input = TaskRunnerIn {}
    output = TaskRunnerOut {}
}

skill s_tooling_task_runner_contract() {
    out TaskRunnerContract {}
}

skill s_tooling_task_runner_stub(in) {
    out TaskRunnerOut {
        passed = no
        output = ""
        diagnostics = []
    }
}
