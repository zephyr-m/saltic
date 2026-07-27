use core
use literal

op = enum {
    nop,
    push,
    pushnone,
    pusherror,
    pushenum,
    load,
    store,
    add,
    sub,
    mul,
    div,
    eq,
    gt,
    lt,
    call,
    pop,
    boxnew,
    field,
    group,
    ifop,
    drumop,
    switchop,
    rescueop,
    returnop,
}

callkind = enum {
    local,
    boundary,
}

instr = Box {
    op = op.nop
    target = ""
    argc = 0
    callkind = callkind.local
    literal = literal {}
    body = none
    cases = []
    fields = []
    span = none
}

skill noop() {
    out instr {}
}

skill push(literal) {
    out instr {
        op = op.push
        literal = literal
    }
}

skill load(name) {
    out instr {
        op = op.load
        target = name
    }
}

skill store(name) {
    out instr {
        op = op.store
        target = name
    }
}

skill localcall(name, argc) {
    out instr {
        op = op.call
        target = name
        argc = argc
        callkind = callkind.local
    }
}

skill boundcall(name, argc) {
    out instr {
        op = op.call
        target = name
        argc = argc
        callkind = callkind.boundary
    }
}

skill ret() {
    out instr {
        op = op.returnop
    }
}
