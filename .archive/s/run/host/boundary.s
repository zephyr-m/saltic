use core

kind = enum {
    core,
    host,
    visual,
    world,
}

call = Box {
    kind = kind.core
    name = ""
    argc = 0
    args = []
    state = none
}

result = Box {
    value = none
    state = none
    handled = no
    effect = none
    error = none
}

handler = Box {
    kind = kind.core
    name = ""
    effect = ""
}

table = Box {
    handlers = []
}

input = Box {
    name = ""
    argc = 0
    args = []
    effect = ""
}

output = Box {
    value = none
    handled = no
    effect = ""
}

contract = Box {
    input = input {}
    output = output {}
}

skill s_host_boundary_contract() {
    out contract {}
}

skill makecall(kind, name, argc, args, state) {
    out call {
        kind = kind
        name = name
        argc = argc
        args = args
        state = state
    }
}

skill makehandler(kind, name, effect) {
    out handler {
        kind = kind
        name = name
        effect = effect
    }
}

skill maketable() {
    out table {
        handlers = []
    }
}

skill addhandler(table, handler) {
    out table {
        handlers = core.group.append(table.handlers, handler)
    }
}

skill s_host_boundary_stub(in) {
    out output {
        value = none
        handled = no
        effect = in.effect
    }
}
