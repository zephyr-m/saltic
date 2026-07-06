use core

EffectsIn = Box {
    effect = ""
    name = ""
    payload = none
}

EffectsOut = Box {
    effect = ""
    known = no
    payload = none
}

EffectsContract = Box {
    input = EffectsIn {}
    output = EffectsOut {}
}

skill s_effects_effects_contract() {
    out EffectsContract {}
}

skill s_effects_effects_stub(in) {
    out EffectsOut {
        effect = in.effect
        known = no
        payload = in.payload
    }
}
