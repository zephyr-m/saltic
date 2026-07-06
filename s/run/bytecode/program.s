use core
use instruction

code = Box {
    name = ""
    params = []
    instructions = []
    arity = 0
    is_entry = no
    span = none
}

boxdecl = Box {
    name = ""
    fields = []
    span = none
}

enumdecl = Box {
    name = ""
    variants = []
    span = none
}

meta = Box {
    boxes = []
    enums = []
    source = ""
    format = "v0"
}

unit = Box {
    entry = "program"
    skills = []
    meta = meta {}
}

decodein = Box {
    artifact = none
    source = ""
    format = "v0"
}

decodeout = Box {
    unit = unit {}
    diagnostics = []
    ok = yes
}

encodein = Box {
    unit = unit {}
    format = "v0"
}

encodeout = Box {
    artifact = none
    diagnostics = []
    ok = yes
}

validatein = Box {
    unit = unit {}
}

validateout = Box {
    diagnostics = []
    ok = yes
}

skill makeskill(name, params, instructions) {
    out code {
        name = name
        params = params
        instructions = instructions
        arity = core.group.count(params)
        is_entry = no
    }
}

skill entryskill(name, params, instructions) {
    out code {
        name = name
        params = params
        instructions = instructions
        arity = core.group.count(params)
        is_entry = yes
    }
}

skill makeunit(entry, skills, meta) {
    out unit {
        entry = entry
        skills = skills
        meta = meta
    }
}

skill decodestub(in) {
    out decodeout {
        unit = unit {
            entry = "program"
            skills = []
            meta = meta {
                source = in.source
                format = in.format
            }
        }
        diagnostics = []
        ok = yes
    }
}

skill encodestub(in) {
    out encodeout {
        artifact = in.unit
        diagnostics = []
        ok = yes
    }
}

skill validstub(in) {
    out validateout {
        diagnostics = []
        ok = yes
    }
}
