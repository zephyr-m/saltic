use core

ProcessRunIn = Box {
    command = ""
}

ProcessRunOut = Box {
    status = 0
}

ProcessContract = Box {
    input = ProcessRunIn {}
    output = ProcessRunOut {}
}

skill s_core_process_contract() {
    out ProcessContract {}
}
