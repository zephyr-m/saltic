use core

ScopeIn = Box {
    env = none
    name = ""
    value = none
    depth = 0
}

ScopeOut = Box {
    env = none
    value = none
    found = no
}

ScopeContract = Box {
    input = ScopeIn {}
    output = ScopeOut {}
}

skill s_runtime_scope_contract() {
    out ScopeContract {}
}

skill s_runtime_scope_stub(in) {
    out ScopeOut {
        env = in.env
        value = in.value
        found = no
    }
}
