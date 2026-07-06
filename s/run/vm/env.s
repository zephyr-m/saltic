use core

EnvIn = Box {
    env = none
    name = ""
    value = none
    count = 0
}

EnvOut = Box {
    env = none
    value = none
    found = no
}

EnvContract = Box {
    input = EnvIn {}
    output = EnvOut {}
}

skill s_vm_env_contract() {
    out EnvContract {}
}

skill s_vm_env_stub(in) {
    out EnvOut {
        env = in.env
        value = in.value
        found = no
    }
}
