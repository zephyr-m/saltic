use core

kind = enum {
    empty,
    num,
    txt,
    flag,
    err,
    var,
}

literal = Box {
    kind = kind.empty
    number = 0
    text = ""
    flag = no
    error = ""
    etype = ""
    variant = ""
}

skill noneval() {
    out literal {}
}

skill numval(value) {
    out literal {
        kind = kind.num
        number = value
    }
}

skill textval(value) {
    out literal {
        kind = kind.txt
        text = value
    }
}

skill flagval(value) {
    out literal {
        kind = kind.flag
        flag = value
    }
}

skill errval(name) {
    out literal {
        kind = kind.err
        error = name
    }
}

skill varval(etype, variant) {
    out literal {
        kind = kind.var
        etype = etype
        variant = variant
    }
}
