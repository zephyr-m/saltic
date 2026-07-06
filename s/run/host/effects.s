use core

HostEffectsIn = Box {
    effect = ""
    name = ""
    args = []
}

HostEffectsOut = Box {
    effect = ""
    handled = no
    trace = ""
}

HostEffectsContract = Box {
    input = HostEffectsIn {}
    output = HostEffectsOut {}
}

skill s_host_effects_contract() {
    out HostEffectsContract {}
}

skill s_host_effects_stub(in) {
    out HostEffectsOut {
        effect = in.effect
        handled = no
        trace = ""
    }
}
