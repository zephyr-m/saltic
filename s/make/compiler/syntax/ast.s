use core

AstIn = Box {
    tokens = []
    path = ""
}

AstOut = Box {
    ast = none
    tokens = []
    path = ""
}

AstContract = Box {
    input = AstIn {}
    output = AstOut {}
}

Ast = Box {
    kind = ""
    name = ""
    params = []
    items = []
    body = []
    value = none
    line = 0
    col = 0
}

skill s_compiler_ast_contract() {
    out AstContract {}
}

skill s_compiler_ast_stub(in) {
    out AstOut {
        ast = none
        tokens = in.tokens
        path = in.path
    }
}

skill ast_program(items) {
    out Ast {
        kind = "PROGRAM"
        name = "program"
        params = []
        items = items
        body = items
    }
}

skill ast_out(value) {
    out Ast {
        kind = "OUT"
        name = "out"
        value = value
        line = value.line
        col = value.col
    }
}

skill ast_literal(kind, value) {
    out Ast {
        kind = kind
        name = "literal"
        value = value
    }
}

skill ast_group(items) {
    out Ast {
        kind = "GROUP"
        name = "group"
        items = items
    }
}

skill ast_box_decl(name, fields) {
    out Ast {
        kind = "BOX_DECL"
        name = name
        items = fields
    }
}

skill ast_box_value(name, fields) {
    out Ast {
        kind = "BOX"
        name = name
        items = fields
    }
}

skill ast_field(owner, name) {
    out Ast {
        kind = "FIELD"
        name = name
        value = owner
        line = owner.line
        col = owner.col
    }
}

skill ast_field_set(owner, name, value) {
    out Ast {
        kind = "FIELD_SET"
        name = name
        items = core.group.add([], owner)
        value = value
        line = owner.line
        col = owner.col
    }
}

skill ast_path(name) {
    out Ast {
        kind = "PATH"
        name = name
        value = name
    }
}

skill ast_with_location(ast, line, col) {
    out Ast {
        kind = ast.kind
        name = ast.name
        params = ast.params
        items = ast.items
        body = ast.body
        value = ast.value
        line = line
        col = col
    }
}

skill ast_call(name, args) {
    out Ast {
        kind = "CALL"
        name = name
        items = args
        value = name
    }
}

skill ast_assign(name, value) {
    out Ast {
        kind = "ASSIGN"
        name = name
        value = value
        line = value.line
        col = value.col
    }
}

skill ast_skill(name, params, body) {
    out Ast {
        kind = "SKILL"
        name = name
        params = params
        body = body
    }
}

skill ast_program_with_body(items, body) {
    out Ast {
        kind = "PROGRAM"
        name = "program"
        params = []
        items = items
        body = body
    }
}

skill ast_if(test, body) {
    out Ast {
        kind = "IF"
        name = "if"
        value = test
        body = body
        line = test.line
        col = test.col
    }
}

skill ast_drum(count, body) {
    out Ast {
        kind = "DRUM"
        name = "drum"
        value = count
        body = body
        line = count.line
        col = count.col
    }
}
