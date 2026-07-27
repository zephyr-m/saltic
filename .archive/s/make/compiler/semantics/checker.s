use core
use s.make.compiler.diagnostic
use s.make.compiler.semantics.scope

CheckerIn = Box {
    ast = none
    path = ""
    scope = none
}

CheckerOut = Box {
    checked = none
    diagnostics = []
    path = ""
}

CheckerContract = Box {
    input = CheckerIn {}
    output = CheckerOut {}
}

skill s_compiler_checker_contract() {
    out CheckerContract {}
}

skill s_compiler_checker_stub(in) {
    out CheckerOut {
        checked = in.ast
        diagnostics = []
        path = in.path
    }
}

skill checker_known_call(name) {
    (name == "host.io.println") { out yes }
    (name == "core.io.show") { out yes }
    (name == "core.io.println") { out yes }
    (name == "core.str.len") { out yes }
    (name == "core.str.at") { out yes }
    (name == "core.str.slice") { out yes }
    (name == "core.str.add") { out yes }
    (name == "core.str.eq") { out yes }
    (name == "core.group.count") { out yes }
    (name == "core.group.at") { out yes }
    (name == "core.group.item") { out yes }
    (name == "core.group.add") { out yes }
    (name == "core.num.add") { out yes }
    (name == "core.num.sub") { out yes }
    (name == "core.num.mul") { out yes }
    (name == "core.num.div") { out yes }
    (name == "core.num.gt") { out yes }
    (name == "core.num.lt") { out yes }
    (name == "core.num.eq") { out yes }
    (name == "core.process.run") { out yes }
    out no
}

skill checker_diagnostic(code, message, path) {
    out checker_diagnostic_at(code, message, path, 0, 0)
}

skill checker_diagnostic_at(code, message, path, line, col) {
    out compiler_diagnostic(code, message, path, line, col)
}

skill checker_skill_arity(skills, name) {
    @index = 0
    @count = core.group.count(skills)
    @arity = 99

    drum (count) {
        (index < count) {
            @decl = core.group.item(skills, index)
            (decl.kind == "SKILL") {
                (decl.name == name) {
                    arity = core.group.count(decl.params)
                }
            }
            index = index + 1
        }
    }

    out arity
}

skill checker_call_args_known(args, scope) {
    @index = 0
    @known = yes
    @count = core.group.count(args)

    drum (count) {
        (index < count) {
            @arg = core.group.item(args, index)
            (arg.kind == "PATH") {
                (scope_has(scope, arg.name) == no) {
                    known = no
                }
            }
            index = index + 1
        }
    }

    out known
}

skill checker_check_program(ast, path) {
    @skill_scope = scope_start()
    @diagnostics = []
    @index = 0
    @body = ast.body
    @count = core.group.count(body)
    @top_count = core.group.count(ast.items)
    @top_index = 0

    drum (top_count) {
        (top_index < top_count) {
            @top = core.group.item(ast.items, top_index)
            (top.kind == "SKILL") {
                (scope_has(skill_scope, top.name) == yes) {
                    diagnostics = core.group.add(diagnostics, checker_diagnostic("duplicate_skill", "duplicate skill", path))
                }
                skill_scope = scope_put(skill_scope, top.name, none)
                @param_scope = scope_start()
                @param_index = 0
                @param_count = core.group.count(top.params)
                drum (param_count) {
                    (param_index < param_count) {
                        @param_name = core.group.item(top.params, param_index)
                        (scope_has(param_scope, param_name) == yes) {
                            diagnostics = core.group.add(diagnostics, checker_diagnostic("duplicate_parameter", "duplicate parameter", path))
                        }
                        param_scope = scope_put(param_scope, param_name, none)
                        param_index = param_index + 1
                    }
                }
            }
            top_index = top_index + 1
        }
    }

    @skill_index = 0
    drum (top_count) {
        (skill_index < top_count) {
            @decl = core.group.item(ast.items, skill_index)
            (decl.kind == "SKILL") {
                @scope = scope_start()
                @param_index = 0
                @param_count = core.group.count(decl.params)
                drum (param_count) {
                    (param_index < param_count) {
                        @param_name = core.group.item(decl.params, param_index)
                        scope = scope_put(scope, param_name, none)
                        param_index = param_index + 1
                    }
                }
                @body_index = 0
                @body_count = core.group.count(decl.body)
                drum (body_count) {
                    (body_index < body_count) {
                        @statement = core.group.item(decl.body, body_index)
                        (statement.kind == "ASSIGN") {
                            @line = statement.value.line
                            @col = statement.value.col
                            (statement.value.kind == "PATH") {
                                (scope_has(scope, statement.value.name) == no) {
                                    diagnostics = core.group.add(diagnostics, checker_diagnostic_at("unknown_name", "unknown name", path, line, col))
                                }
                            }
                            (statement.value.kind == "CALL") {
                                (checker_known_call(statement.value.name) == no) {
                                    @assign_arity = checker_skill_arity(ast.items, statement.value.name)
                                    (assign_arity == 99) {
                                        diagnostics = core.group.add(diagnostics, checker_diagnostic_at("unknown_call", "unknown call", path, line, col))
                                    }
                                    (assign_arity < 99) {
                                        (checker_call_args_known(statement.value.items, scope) == no) {
                                            diagnostics = core.group.add(diagnostics, checker_diagnostic_at("unknown_name", "unknown argument name", path, line, col))
                                        }
                                    }
                                }
                            }
                            scope = scope_put(scope, statement.name, none)
                        }
                        (statement.kind == "OUT") {
                            @line = statement.value.line
                            @col = statement.value.col
                            (statement.value.kind == "PATH") {
                                (scope_has(scope, statement.value.name) == no) {
                                    diagnostics = core.group.add(diagnostics, checker_diagnostic_at("unknown_name", "unknown name", path, line, col))
                                }
                            }
                            (statement.value.kind == "CALL") {
                                (checker_known_call(statement.value.name) == no) {
                                    @call_arity = checker_skill_arity(ast.items, statement.value.name)
                                    (call_arity == 99) {
                                        diagnostics = core.group.add(diagnostics, checker_diagnostic_at("unknown_call", "unknown call", path, line, col))
                                    }
                                    (call_arity < 99) {
                                        (checker_call_args_known(statement.value.items, scope) == no) {
                                            diagnostics = core.group.add(diagnostics, checker_diagnostic_at("unknown_name", "unknown argument name", path, line, col))
                                        }
                                        (call_arity < core.group.count(statement.value.items)) {
                                            diagnostics = core.group.add(diagnostics, checker_diagnostic_at("wrong_arity", "wrong argument count", path, line, col))
                                        }
                                        (call_arity > core.group.count(statement.value.items)) {
                                            diagnostics = core.group.add(diagnostics, checker_diagnostic_at("wrong_arity", "wrong argument count", path, line, col))
                                        }
                                    }
                                }
                            }
                        }
                        body_index = body_index + 1
                    }
                }
            }
            skill_index = skill_index + 1
        }
    }

    @program_scope = scope_start()
    drum (count) {
        @item = core.group.item(body, index)
        @line = item.value.line
        @col = item.value.col
        (item.kind == "ASSIGN") {
            (item.value.kind == "PATH") {
                (scope_has(program_scope, item.value.name) == no) {
                    diagnostics = core.group.add(diagnostics, checker_diagnostic_at("unknown_name", "unknown name", path, line, col))
                }
            }
            (item.value.kind == "CALL") {
                (checker_known_call(item.value.name) == no) {
                    @assign_arity = checker_skill_arity(ast.items, item.value.name)
                    (assign_arity == 99) {
                        diagnostics = core.group.add(diagnostics, checker_diagnostic_at("unknown_call", "unknown call", path, line, col))
                    }
                    (assign_arity < 99) {
                        (checker_call_args_known(item.value.items, program_scope) == no) {
                            diagnostics = core.group.add(diagnostics, checker_diagnostic_at("unknown_name", "unknown argument name", path, line, col))
                        }
                    }
                }
            }
            program_scope = scope_put(program_scope, item.name, none)
        }
        (item.kind == "OUT") {
            (item.value.kind == "PATH") {
                (scope_has(program_scope, item.value.name) == no) {
                    diagnostics = core.group.add(diagnostics, checker_diagnostic_at("unknown_name", "unknown name", path, line, col))
                }
            }
            (item.value.kind == "CALL") {
                (checker_known_call(item.value.name) == no) {
                    @arity = checker_skill_arity(ast.items, item.value.name)
                    (arity == 99) {
                        diagnostics = core.group.add(diagnostics, checker_diagnostic_at("unknown_call", "unknown call", path, line, col))
                    }
                    (arity < 99) {
                        (checker_call_args_known(item.value.items, program_scope) == no) {
                            diagnostics = core.group.add(diagnostics, checker_diagnostic_at("unknown_name", "unknown argument name", path, line, col))
                        }
                        (arity == core.group.count(item.value.items)) {
                        }
                        (arity < core.group.count(item.value.items)) {
                            diagnostics = core.group.add(diagnostics, checker_diagnostic_at("wrong_arity", "wrong argument count", path, line, col))
                        }
                        (arity > core.group.count(item.value.items)) {
                            diagnostics = core.group.add(diagnostics, checker_diagnostic_at("wrong_arity", "wrong argument count", path, line, col))
                        }
                    }
                }
            }
        }
        index = index + 1
    }

    out CheckerOut {
        checked = ast
        diagnostics = diagnostics
        path = path
    }
}
