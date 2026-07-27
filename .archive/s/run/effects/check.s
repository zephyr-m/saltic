use core

EffectsCheckIn = Box {
    effect = ""
    scope = ""
    details = []
}

EffectsCheckOut = Box {
    ok = no
    diagnostics = []
    details = []
}

EffectsCheckContract = Box {
    input = EffectsCheckIn {}
    output = EffectsCheckOut {}
}

skill s_effects_check_contract() {
    out EffectsCheckContract {}
}

skill s_effects_check_stub(in) {
    out EffectsCheckOut {
        ok = no
        diagnostics = []
        details = in.details
    }
}
