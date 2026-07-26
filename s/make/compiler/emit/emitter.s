use core

Ir = Box {
    op = ""
    name = ""
    args = []
    value = none
    body = []
}

skill ir_args(args) {
    @result = []
    @index = 0
    @count = core.group.count(args)
    drum (count) {
        (index < count) {
            @arg = core.group.item(args, index)
            result = core.group.add(result, ir_value(arg))
            index = index + 1
        }
    }
    out result
}

skill ir_body(body) {
    @result = []
    @index = 0
    @count = core.group.count(body)
    drum (count) {
        (index < count) {
            @statement = core.group.item(body, index)
            result = core.group.add(result, ir_statement(statement))
            index = index + 1
        }
    }
    out result
}

EmitOut = Box {
    instructions = []
    diagnostics = []
}

skill ir_value(ast) {
    (ast.kind == "BOX") {
        out Ir {
            op = "BOX"
            name = ast.name
            body = ir_body(ast.items)
        }
    }
    (ast.kind == "FIELD") {
        out Ir {
            op = "FIELD"
            name = ast.name
            value = ir_value(ast.value)
        }
    }
    (ast.kind == "GROUP") {
        out Ir {
            op = "GROUP"
            name = ast.name
            args = ir_args(ast.items)
        }
    }
    (ast.kind == "CALL") {
        (ast.name == "core.io.show") {
            out Ir {
                op = "WRITE"
                name = ast.name
                args = ir_args(ast.items)
            }
        }
        (ast.name == "core.process.run") {
            out Ir {
                op = "PROCESS_RUN"
                name = ast.name
                args = ir_args(ast.items)
            }
        }
        out Ir {
            op = "CALL"
            name = ast.name
            args = ir_args(ast.items)
        }
    }
    out Ir {
        op = ast.kind
        name = ast.name
        value = ast.value
    }
}

skill ir_statement(ast) {
    (ast.kind == "FIELD_SET") {
        out Ir {
            op = "FIELD_SET"
            name = ast.name
            args = ir_args(ast.items)
            value = ir_value(ast.value)
        }
    }
    (ast.kind == "CALL") {
        (ast.name == "core.io.show") {
            out Ir {
                op = "WRITE"
                name = ast.name
                args = ir_args(ast.items)
            }
        }
        (ast.name == "core.process.run") {
            out Ir {
                op = "PROCESS_RUN"
                name = ast.name
                args = ir_args(ast.items)
            }
        }
    }
    (ast.kind == "IF") {
        out Ir {
            op = "IF"
            name = ast.name
            value = ir_value(ast.value)
            body = ir_body(ast.body)
        }
    }
    (ast.kind == "DRUM") {
        out Ir {
            op = "DRUM"
            name = ast.name
            value = ir_value(ast.value)
            body = ir_body(ast.body)
        }
    }
    (ast.kind == "ASSIGN") {
        out Ir {
            op = "ASSIGN"
            name = ast.name
            value = ir_value(ast.value)
        }
    }
    (ast.kind == "OUT") {
        (ast.value.kind == "CALL") {
            (ast.value.name == "core.io.show") {
                out Ir {
                    op = "WRITE"
                    name = ast.value.name
                    args = ir_args(ast.value.items)
                }
            }
            (ast.value.name == "core.process.run") {
                out Ir {
                    op = "PROCESS_RUN"
                    name = ast.value.name
                    args = ir_args(ast.value.items)
                }
            }
        }
        out Ir {
            op = "OUT"
            name = ast.name
            value = ir_value(ast.value)
        }
    }
    out Ir {
        op = ast.kind
        name = ast.name
        value = ast.value
    }
}

skill emit_skill(ast) {
    @instructions = []
    @index = 0
    @count = core.group.count(ast.body)

    drum (count) {
        (index < count) {
            @statement = core.group.item(ast.body, index)
            instructions = core.group.add(instructions, ir_statement(statement))
            index = index + 1
        }
    }

    out Ir {
        op = "SKILL"
        name = ast.name
        args = ast.params
        body = instructions
    }
}

skill emit_box(ast) {
    out Ir {
        op = "BOX_DECL"
        name = ast.name
        body = ir_body(ast.items)
    }
}

skill compiler_emit(ast) {
    @instructions = []
    @index = 0
    @count = core.group.count(ast.items)

    drum (count) {
        (index < count) {
            @item = core.group.item(ast.items, index)
            (item.kind == "SKILL") {
                instructions = core.group.add(instructions, emit_skill(item))
            }
            (item.kind == "BOX_DECL") {
                instructions = core.group.add(instructions, emit_box(item))
            }
            index = index + 1
        }
    }

    @body_index = 0
    @body_count = core.group.count(ast.body)
    drum (body_count) {
        (body_index < body_count) {
            @statement = core.group.item(ast.body, body_index)
            instructions = core.group.add(instructions, ir_statement(statement))
            body_index = body_index + 1
        }
    }

    out EmitOut {
        instructions = instructions
        diagnostics = []
    }
}
