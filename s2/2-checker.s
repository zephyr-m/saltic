use core

SalticNode = Box {
    datum = []
    tag = ""
}

CheckName = Box {
    name = ""
    kind = ""
    type = "unknown"
    node = []
}

CheckDiagnostic = Box {
    code = "checker_error"
    message = ""
    line = 0
    col = 0
}

CheckResult = Box {
    diagnostics = []
    globals = []
}

CheckScope = Box {
    names = []
    subject = ""
}

skill checker_plain(node) {
    (core.group.count(node) == 4) {
        (core.group.item(node, 0) == "loc") { out core.group.item(node, 3) }
    }
    out node
}

skill checker_tag(node) {
    @plain = checker_plain(node)
    out core.group.item(plain, 0)
}

skill checker_part(node, index) {
    @plain = checker_plain(node)
    out core.group.item(plain, index)
}

skill checker_location(node) {
    (core.group.count(node) == 4) {
        (core.group.item(node, 0) == "loc") { out [core.group.item(node, 1), core.group.item(node, 2)] }
    }
    out [0, 0]
}

skill checker_diagnostic(node, code, message) {
    @place = checker_location(node)
    out CheckDiagnostic {
        code = code
        message = message
        line = core.group.item(place, 0)
        col = core.group.item(place, 1)
    }
}

skill checker_add(diagnostics, diagnostic) {
    out core.group.add(diagnostics, diagnostic)
}

skill checker_find(names, name) {
    @result = CheckName {}
    @found = no
    @index = 0
    @count = core.group.count(names)
    drum (count) {
        (found == no) {
            @item = core.group.item(names, index)
            (item.name == name) { result = item found = yes }
        }
        index = index + 1
    }
    out result
}

skill checker_has(names, name) {
    @found = checker_find(names, name)
    out core.str.len(found.name) > 0
}

skill checker_put(names, name, kind, type) {
    out core.group.add(names, CheckName { name = name kind = kind type = type })
}

skill checker_put_node(names, name, kind, type, node) {
    out core.group.add(names, CheckName { name = name kind = kind type = type node = node })
}

skill checker_update(names, name, type) {
    @result = []
    @index = 0
    @count = core.group.count(names)
    drum (count) {
        @item = core.group.item(names, index)
        @next_type = item.type
        (item.name == name) { next_type = type }
        result = checker_put_node(result, item.name, item.kind, next_type, item.node)
        index = index + 1
    }
    out result
}

skill checker_tail(text, start) {
    out core.str.slice(text, start, core.str.len(text))
}

skill checker_group_type(type) {
    out core.str.add("group:", type)
}

skill checker_is_group_type(type) {
    out core.str.starts_with(type, "group:")
}

skill checker_group_item_type(type) {
    (checker_is_group_type(type) == yes) { out checker_tail(type, 6) }
    out "unknown"
}

skill checker_merge(left, right) {
    (left == "unknown") { out right }
    (right == "unknown") { out left }
    (left == right) { out left }
    (checker_is_group_type(left) == yes) {
        (checker_is_group_type(right) == yes) { out checker_group_type(checker_merge(checker_group_item_type(left), checker_group_item_type(right))) }
    }
    out "unknown"
}

skill checker_compatible(left, right) {
    (left == "unknown") { out yes }
    (right == "unknown") { out yes }
    (left == right) { out yes }
    (checker_is_group_type(left) == yes) {
        (checker_is_group_type(right) == yes) { out checker_compatible(checker_group_item_type(left), checker_group_item_type(right)) }
    }
    out no
}

skill checker_type_text(type) {
    (type == "answer") { out "yes/no" }
    (core.str.starts_with(type, "box:") == yes) { out core.str.add("Box ", checker_tail(type, 4)) }
    (core.str.starts_with(type, "enum:") == yes) { out core.str.add("enum ", checker_tail(type, 5)) }
    (checker_is_group_type(type) == yes) { out core.str.add("Group ", checker_type_text(checker_group_item_type(type))) }
    out type
}

skill checker_type(node) {
    @tag = checker_tag(node)
    (tag == "number") { out "number" }
    (tag == "string") { out "string" }
    (tag == "answer") { out "answer" }
    (tag == "none") { out "none" }
    (tag == "group") {
        @type = "unknown"
        @index = 1
        @plain = checker_plain(node)
        @count = core.group.count(plain)
        drum (count) {
            (index < count) { type = checker_merge(type, checker_type(core.group.item(plain, index))) }
            index = index + 1
        }
        out checker_group_type(type)
    }
    (tag == "box-new") { out core.str.add("box:", checker_part(node, 1)) }
    out "unknown"
}

skill checker_collect(ast) {
    @result = CheckResult {}
    @program_seen = no
    @index = 1
    @count = core.group.count(ast)
    drum (count) {
        (index < count) {
            @item = core.group.item(ast, index)
            @tag = checker_tag(item)
            @name = ""
            @kind = ""
            (tag == "use") {
                (checker_part(item, 1) == "core") {
                    (checker_has(result.globals, "__core__") == no) { result.globals = checker_put(result.globals, "__core__", "import", "module-path") }
                }
            }
            (tag == "entry") {
                (program_seen == yes) { result.diagnostics = checker_add(result.diagnostics, CheckDiagnostic { code = "duplicate_definition" message = "duplicate program entry" }) }
                program_seen = yes
            }
            (tag == "const") { name = checker_part(item, 1) kind = "const" }
            (tag == "enum") { name = checker_part(item, 1) kind = "enum" }
            (tag == "box") { name = checker_part(item, 1) kind = "box" }
            (tag == "skill") { name = checker_part(item, 1) kind = "skill" }
            (core.str.len(name) > 0) {
                (checker_has(result.globals, name) == yes) {
                    result.diagnostics = checker_add(result.diagnostics, CheckDiagnostic { code = "duplicate_definition" message = core.str.add("duplicate top-level name '", core.str.add(name, "'")) })
                }
                @type = "unknown"
                (kind == "const") { type = checker_type(checker_part(item, 2)) }
                (kind == "enum") { type = "enum-type" }
                (kind == "box") { type = "box-type" }
                (kind == "skill") { type = "function" }
                (checker_has(result.globals, name) == no) { result.globals = checker_put_node(result.globals, name, kind, type, item) }
            }
            index = index + 1
        }
    }
    out result
}

skill checker_box_field(globals, box_name, field_name) {
    @box = checker_find(globals, box_name)
    @result = CheckName {}
    @index = 2
    @count = core.group.count(checker_plain(box.node))
    drum (count) {
        (index < count) {
            @member = checker_part(box.node, index)
            (checker_tag(member) == "field") {
                (checker_part(member, 1) == field_name) { result = CheckName { name = field_name kind = "field" type = checker_type(checker_part(member, 2)) node = member } }
            }
            index = index + 1
        }
    }
    out result
}

skill checker_box_has_skill(globals, box_name, skill_name) {
    @box = checker_find(globals, box_name)
    @found = no
    @index = 2
    @count = core.group.count(checker_plain(box.node))
    drum (count) {
        (index < count) {
            @member = checker_part(box.node, index)
            (checker_tag(member) == "subject-skill") {
                (checker_part(member, 1) == skill_name) { found = yes }
            }
            index = index + 1
        }
    }
    out found
}

skill checker_enum_has(globals, enum_name, variant) {
    @model = checker_find(globals, enum_name)
    @found = no
    @index = 2
    @count = core.group.count(checker_plain(model.node))
    drum (count) {
        (index < count) {
            (checker_part(model.node, index) == variant) { found = yes }
            index = index + 1
        }
    }
    out found
}

skill checker_path_type(node, scope, globals) {
    @parts = checker_plain(node)
    @count = core.group.count(parts)
    @name = core.group.item(parts, 1)
    (count == 2) {
        @local = checker_find(scope.names, name)
        (core.str.len(local.name) > 0) { out local.type }
        @global = checker_find(globals, name)
        (core.str.len(global.name) > 0) { out global.type }
        (name == "error") { out "error" }
        out "unknown"
    }
    (name == "host") { out "module-path" }
    (name == "world") { out "module-path" }
    (name == "visual") { out "module-path" }
    (name == "ui") { out "module-path" }
    (name == "core") { out "module-path" }
    (name == "error") { out "error" }
    @enum_model = checker_find(globals, name)
    (enum_model.kind == "enum") {
        (count == 3) { out core.str.add("enum:", name) }
    }
    @local_value = checker_find(scope.names, name)
    @type = local_value.type
    (type == "unknown") {
        @global_value = checker_find(globals, name)
        type = global_value.type
    }
    @index = 2
    drum (count) {
        (index < count) {
            @was_box = core.str.starts_with(type, "box:")
            (was_box == yes) {
                @field = checker_box_field(globals, checker_tail(type, 4), core.group.item(parts, index))
                type = field.type
            }
            (was_box == no) { type = "unknown" }
            index = index + 1
        }
    }
    out type
}

skill checker_call_type(node, scope, globals) {
    @plain = checker_plain(node)
    @callee = checker_plain(core.group.item(plain, 1))
    (core.group.item(callee, 0) == "path") {
        @name = core.group.item(callee, 1)
        @part_count = core.group.count(callee)
        (part_count == 2) {
            @global = checker_find(globals, name)
            (global.kind == "box") { out core.str.add("box:", name) }
        }
        @full = name
        @part_index = 2
        drum (part_count) {
            (part_index < part_count) { full = core.str.add(full, core.str.add(".", core.group.item(callee, part_index))) part_index = part_index + 1 }
        }
        (full == "core.group.count") { out "number" }
        (full == "core.group.at") { out checker_group_item_type(checker_value_type(core.group.item(plain, 2), scope, globals)) }
        (full == "core.group.item") { out checker_group_item_type(checker_value_type(core.group.item(plain, 2), scope, globals)) }
        (full == "core.group.add") { out checker_group_type(checker_merge(checker_group_item_type(checker_value_type(core.group.item(plain, 2), scope, globals)), checker_value_type(core.group.item(plain, 3), scope, globals))) }
        (full == "core.group.append") { out checker_group_type(checker_merge(checker_group_item_type(checker_value_type(core.group.item(plain, 2), scope, globals)), checker_value_type(core.group.item(plain, 3), scope, globals))) }
        (full == "core.mem.load8") { out "number" }
        (full == "core.mem.load16") { out "number" }
        (full == "core.mem.load32") { out "number" }
        (full == "core.mem.store8") { out "none" }
        (full == "core.mem.store16") { out "none" }
        (full == "core.mem.store32") { out "none" }
        (full == "core.mem.store_address32") { out "none" }
        (full == "core.cpu.wait") { out "none" }
        (full == "core.cpu.fence") { out "none" }
        (full == "core.file.read") { out "string" }
        (full == "core.str.line_count") { out "number" }
        (full == "core.str.len") { out "number" }
        (full == "core.str.at") { out "string" }
        (full == "core.str.byte") { out "number" }
        (full == "core.str.slice") { out "string" }
        (full == "core.str.join") { out "string" }
        (full == "core.str.add") { out "string" }
        (full == "core.str.eq") { out "answer" }
        (full == "core.str.is_empty") { out "answer" }
        (full == "core.str.starts_with") { out "answer" }
        (full == "core.str.ends_with") { out "answer" }
        (full == "core.str.contains") { out "answer" }
        (full == "core.str.trim") { out "string" }
        (full == "core.str.upper") { out "string" }
        (full == "core.str.lower") { out "string" }
        (full == "core.str.split") { out "group:string" }
        (full == "core.num.parse") { out "number" }
        (full == "core.num.abs") { out "number" }
        (full == "core.num.min") { out "number" }
        (full == "core.num.max") { out "number" }
        (full == "core.num.round") { out "number" }
        (full == "core.io.show") { out "none" }
        (full == "core.file.write") { out "none" }
    }
    out "unknown"
}

skill checker_block_value_type(block, scope, globals) {
    @plain = checker_plain(block)
    @count = core.group.count(plain)
    (count == 1) { out "none" }
    @last = checker_plain(core.group.item(plain, count - 1))
    @tag = core.group.item(last, 0)
    (tag == "expr") { out checker_value_type(core.group.item(last, 1), scope, globals) }
    (tag == "out") { out checker_value_type(core.group.item(last, 1), scope, globals) }
    out "none"
}

skill checker_value_type(node, scope, globals) {
    @plain = checker_plain(node)
    @tag = core.group.item(plain, 0)
    (tag == "number") { out "number" }
    (tag == "string") { out "string" }
    (tag == "answer") { out "answer" }
    (tag == "none") { out "none" }
    (tag == "enum-value") { out "enum-value" }
    (tag == "path") { out checker_path_type(node, scope, globals) }
    (tag == "box-new") { out core.str.add("box:", core.group.item(plain, 1)) }
    (tag == "call") { out checker_call_type(node, scope, globals) }
    (tag == "group") {
        @type = "unknown"
        @index = 1
        @count = core.group.count(plain)
        drum (count) {
            (index < count) { type = checker_merge(type, checker_value_type(core.group.item(plain, index), scope, globals)) }
            index = index + 1
        }
        out checker_group_type(type)
    }
    (tag == "binary") {
        @operator = core.group.item(plain, 1)
        (operator == "==") { out "answer" }
        (operator == ">") { out "answer" }
        (operator == "<") { out "answer" }
        out "number"
    }
    (tag == "rescue") {
        @left = checker_value_type(core.group.item(plain, 1), scope, globals)
        @child = CheckScope { names = scope.names subject = scope.subject }
        child.names = checker_put(child.names, core.group.item(plain, 2), "variable", "error")
        out checker_merge(left, checker_block_value_type(core.group.item(plain, 3), child, globals))
    }
    out "unknown"
}

skill checker_path(node, scope, globals, diagnostics) {
    @parts = checker_plain(node)
    @name = core.group.item(parts, 1)
    @count = core.group.count(parts)
    (count == 2) {
        @known = checker_has(scope.names, name)
        (known == no) { known = checker_has(globals, name) }
        (name == "error") { known = yes }
        (known == no) { out checker_add(diagnostics, checker_diagnostic(node, "unknown_name", core.str.add("unknown name '", core.str.add(name, "'")))) }
        out diagnostics
    }
    (name == "host") { out diagnostics }
    (name == "world") { out diagnostics }
    (name == "visual") { out diagnostics }
    (name == "ui") { out diagnostics }
    (name == "error") { out diagnostics }
    (name == "core") {
        (checker_has(globals, "__core__") == no) { out checker_add(diagnostics, checker_diagnostic(node, "core_not_imported", "module 'core' is not imported; add 'use core'")) }
        out diagnostics
    }
    @global = checker_find(globals, name)
    (global.kind == "enum") {
        (count == 3) {
            @variant = core.group.item(parts, 2)
            (checker_enum_has(globals, name, variant) == no) { out checker_add(diagnostics, checker_diagnostic(node, "checker_error", core.str.add("enum '", core.str.add(name, core.str.add("' has no variant '", core.str.add(variant, "'")))))) }
            out diagnostics
        }
    }
    @base = checker_find(scope.names, name)
    (core.str.len(base.name) == 0) { base = global }
    (core.str.len(base.name) == 0) { out diagnostics }
    @type = base.type
    @index = 2
    drum (count) {
        (index < count) {
            @field_name = core.group.item(parts, index)
            (type == "unknown") { index = count }
            (index < count) {
                @was_box = core.str.starts_with(type, "box:")
                (was_box == yes) {
                    @box_name = checker_tail(type, 4)
                    @field = checker_box_field(globals, box_name, field_name)
                    (core.str.len(field.name) == 0) {
                        @message = core.str.add("Box '", box_name)
                        message = core.str.add(message, "' has no field '")
                        message = core.str.add(message, field_name)
                        message = core.str.add(message, "'")
                        diagnostics = checker_add(diagnostics, checker_diagnostic(node, "checker_error", message))
                        index = count
                    }
                    (core.str.len(field.name) > 0) { type = field.type }
                }
                (was_box == no) {
                    @message = core.str.add("cannot access field '", field_name)
                    message = core.str.add(message, "' on ")
                    message = core.str.add(message, checker_type_text(type))
                    diagnostics = checker_add(diagnostics, checker_diagnostic(node, "checker_error", message))
                    index = count
                }
            }
            index = index + 1
        }
    }
    out diagnostics
}

skill checker_expression(node, scope, globals, diagnostics) {
    @plain = checker_plain(node)
    @tag = core.group.item(plain, 0)
    (tag == "path") { out checker_path(node, scope, globals, diagnostics) }
    (tag == "binary") {
        @left_node = core.group.item(plain, 2)
        @right_node = core.group.item(plain, 3)
        diagnostics = checker_expression(left_node, scope, globals, diagnostics)
        diagnostics = checker_expression(right_node, scope, globals, diagnostics)
        @operator = core.group.item(plain, 1)
        @numeric = no
        (operator == "+") { numeric = yes }
        (operator == "-") { numeric = yes }
        (operator == "*") { numeric = yes }
        (operator == "/") { numeric = yes }
        (operator == ">") { numeric = yes }
        (operator == "<") { numeric = yes }
        (numeric == yes) {
            @left_type = checker_value_type(left_node, scope, globals)
            @right_type = checker_value_type(right_node, scope, globals)
            @known_types = yes
            (left_type == "unknown") { known_types = no }
            (right_type == "unknown") { known_types = no }
            (known_types == yes) {
                @both_numbers = no
                (left_type == "number") {
                    (right_type == "number") { both_numbers = yes }
                }
                (both_numbers == no) {
                    @message = core.str.add("operator '", operator)
                    message = core.str.add(message, "' expects numbers, got ")
                    message = core.str.add(message, checker_type_text(left_type))
                    message = core.str.add(message, " and ")
                    message = core.str.add(message, checker_type_text(right_type))
                    diagnostics = checker_add(diagnostics, CheckDiagnostic { code = "operator_type_mismatch" message = message })
                }
            }
        }
        out diagnostics
    }
    (tag == "call") {
        @callee = checker_plain(core.group.item(plain, 1))
        @skip_callee = no
        (core.group.item(callee, 0) == "path") {
            @callee_count = core.group.count(callee)
            (callee_count == 2) {
                (core.str.len(scope.subject) > 0) {
                    (checker_box_has_skill(globals, scope.subject, core.group.item(callee, 1)) == yes) { skip_callee = yes }
                }
            }
            (callee_count == 3) {
                @receiver_path = ["path", core.group.item(callee, 1)]
                @receiver_type = checker_path_type(receiver_path, scope, globals)
                (core.str.starts_with(receiver_type, "box:") == yes) {
                    (checker_box_has_skill(globals, checker_tail(receiver_type, 4), core.group.item(callee, 2)) == yes) { skip_callee = yes }
                }
            }
        }
        @index = 1
        (skip_callee == yes) { index = 2 }
        @count = core.group.count(plain)
        drum (count) {
            (index < count) { diagnostics = checker_expression(core.group.item(plain, index), scope, globals, diagnostics) }
            index = index + 1
        }
        out diagnostics
    }
    (tag == "group") {
        @index = 1
        @count = core.group.count(plain)
        drum (count) {
            (index < count) { diagnostics = checker_expression(core.group.item(plain, index), scope, globals, diagnostics) }
            index = index + 1
        }
        out diagnostics
    }
    (tag == "box-new") {
        @name = core.group.item(plain, 1)
        @model = checker_find(globals, name)
        (model.kind == "box") {
            @seen = []
            @index = 2
            @count = core.group.count(plain)
            drum (count) {
                (index < count) {
                    @override = core.group.item(plain, index)
                    @field_name = checker_part(override, 1)
                    @value = checker_part(override, 2)
                    diagnostics = checker_expression(value, scope, globals, diagnostics)
                    (checker_has(seen, field_name) == yes) {
                        @message = core.str.add("duplicate field '", field_name)
                        message = core.str.add(message, "' in Box literal '")
                        message = core.str.add(message, name)
                        message = core.str.add(message, "'")
                        diagnostics = checker_add(diagnostics, checker_diagnostic(node, "duplicate_definition", message))
                    }
                    seen = checker_put(seen, field_name, "field", "unknown")
                    @field = checker_box_field(globals, name, field_name)
                    (core.str.len(field.name) == 0) {
                        @message = core.str.add("Box '", name)
                        message = core.str.add(message, "' has no field '")
                        message = core.str.add(message, field_name)
                        message = core.str.add(message, "'")
                        diagnostics = checker_add(diagnostics, checker_diagnostic(node, "checker_error", message))
                    }
                    (core.str.len(field.name) > 0) {
                        @value_type = checker_value_type(value, scope, globals)
                        (checker_compatible(field.type, value_type) == no) {
                            @message = core.str.add("cannot assign ", checker_type_text(value_type))
                            message = core.str.add(message, " to field '")
                            message = core.str.add(message, field_name)
                            message = core.str.add(message, "' of Box '")
                            message = core.str.add(message, name)
                            message = core.str.add(message, "' with type ")
                            message = core.str.add(message, checker_type_text(field.type))
                            diagnostics = checker_add(diagnostics, checker_diagnostic(node, "checker_error", message))
                        }
                    }
                    index = index + 1
                }
            }
            out diagnostics
        }
        @message = core.str.add("unknown Box '", name)
        message = core.str.add(message, "'")
        diagnostics = checker_add(diagnostics, checker_diagnostic(node, "checker_error", message))
        out diagnostics
    }
    (tag == "rescue") {
        diagnostics = checker_expression(core.group.item(plain, 1), scope, globals, diagnostics)
        @child = CheckScope { names = scope.names subject = scope.subject }
        child.names = checker_put(child.names, core.group.item(plain, 2), "variable", "error")
        out checker_block(core.group.item(plain, 3), child, globals, diagnostics)
    }
    out diagnostics
}

skill checker_statement(node, scope, globals, diagnostics) {
    @plain = checker_plain(node)
    @tag = core.group.item(plain, 0)
    (tag == "var") {
        @name = core.group.item(plain, 1)
        @value = core.group.item(plain, 2)
        diagnostics = checker_expression(value, scope, globals, diagnostics)
        (checker_has(scope.names, name) == yes) { diagnostics = checker_add(diagnostics, checker_diagnostic(node, "checker_error", core.str.add("variable '", core.str.add(name, "' is already declared in this scope")))) }
        (checker_has(scope.names, name) == no) {
            (checker_has(globals, name) == yes) {
                @message = core.str.add("variable '", name)
                message = core.str.add(message, "' conflicts with top-level name")
                diagnostics = checker_add(diagnostics, checker_diagnostic(node, "checker_error", message))
            }
            (checker_has(globals, name) == no) { scope.names = checker_put(scope.names, name, "variable", checker_value_type(value, scope, globals)) }
        }
        out diagnostics
    }
    (tag == "assign") {
        @name = core.group.item(plain, 1)
        @value = core.group.item(plain, 2)
        diagnostics = checker_expression(value, scope, globals, diagnostics)
        (checker_has(scope.names, name) == yes) {
            @old = checker_find(scope.names, name)
            @value_type = checker_value_type(value, scope, globals)
            (checker_compatible(old.type, value_type) == yes) { scope.names = checker_update(scope.names, name, checker_merge(old.type, value_type)) }
            (checker_compatible(old.type, value_type) == no) {
                @message = core.str.add("cannot assign ", checker_type_text(value_type))
                message = core.str.add(message, " to variable '")
                message = core.str.add(message, name)
                message = core.str.add(message, "' of type ")
                message = core.str.add(message, checker_type_text(old.type))
                diagnostics = checker_add(diagnostics, checker_diagnostic(node, "type_mismatch", message))
            }
        }
        (checker_has(scope.names, name) == no) {
            @global = checker_find(globals, name)
            @is_constant = no
            (global.kind == "const") { is_constant = yes }
            (global.kind == "const") { diagnostics = checker_add(diagnostics, checker_diagnostic(node, "constant_assignment", core.str.add("cannot assign to constant '", core.str.add(name, "'")))) }
            (core.str.len(global.name) > 0) {
                (is_constant == no) {
                    @message = core.str.add("cannot assign to top-level name '", name)
                    message = core.str.add(message, "'")
                    diagnostics = checker_add(diagnostics, checker_diagnostic(node, "checker_error", message))
                }
            }
            (core.str.len(global.name) == 0) { diagnostics = checker_add(diagnostics, checker_diagnostic(node, "variable_not_declared", core.str.add("variable '", core.str.add(name, "' is not declared")))) }
        }
        out diagnostics
    }
    (tag == "field-assign") {
        @target = checker_plain(core.group.item(plain, 1))
        @part_count = core.group.count(target)
        @base_parts = ["path"]
        @part_index = 1
        drum (part_count) {
            (part_index + 1 < part_count) { base_parts = core.group.add(base_parts, core.group.item(target, part_index)) }
            part_index = part_index + 1
        }
        diagnostics = checker_path(base_parts, scope, globals, diagnostics)
        @value = core.group.item(plain, 2)
        diagnostics = checker_expression(value, scope, globals, diagnostics)
        @base_type = checker_path_type(base_parts, scope, globals)
        (core.str.starts_with(base_type, "box:") == yes) {
            @box_name = checker_tail(base_type, 4)
            @field_name = core.group.item(target, part_count - 1)
            @field = checker_box_field(globals, box_name, field_name)
            (core.str.len(field.name) == 0) {
                @message = core.str.add("Box '", box_name)
                message = core.str.add(message, "' has no field '")
                message = core.str.add(message, field_name)
                message = core.str.add(message, "'")
                diagnostics = checker_add(diagnostics, checker_diagnostic(node, "checker_error", message))
            }
            (core.str.len(field.name) > 0) {
                @value_type = checker_value_type(value, scope, globals)
                (checker_compatible(field.type, value_type) == no) {
                    @message = core.str.add("cannot assign ", checker_type_text(value_type))
                    message = core.str.add(message, " to field '")
                    message = core.str.add(message, field_name)
                    message = core.str.add(message, "' of Box '")
                    message = core.str.add(message, box_name)
                    message = core.str.add(message, "'")
                    diagnostics = checker_add(diagnostics, checker_diagnostic(node, "checker_error", message))
                }
            }
        }
        out diagnostics
    }
    (tag == "out") { out checker_expression(core.group.item(plain, 1), scope, globals, diagnostics) }
    (tag == "expr") { out checker_expression(core.group.item(plain, 1), scope, globals, diagnostics) }
    (tag == "if") {
        diagnostics = checker_expression(core.group.item(plain, 1), scope, globals, diagnostics)
        out checker_block(core.group.item(plain, 2), CheckScope { names = scope.names subject = scope.subject }, globals, diagnostics)
    }
    (tag == "drum") {
        diagnostics = checker_expression(core.group.item(plain, 1), scope, globals, diagnostics)
        out checker_block(core.group.item(plain, 2), CheckScope { names = scope.names subject = scope.subject }, globals, diagnostics)
    }
    (tag == "switch") {
        diagnostics = checker_expression(core.group.item(plain, 1), scope, globals, diagnostics)
        @index = 2
        @count = core.group.count(plain)
        drum (count) {
            (index < count) { diagnostics = checker_expression(checker_part(core.group.item(plain, index), 2), scope, globals, diagnostics) }
            index = index + 1
        }
        out diagnostics
    }
    out checker_add(diagnostics, checker_diagnostic(node, "checker_error", core.str.add("unsupported statement ", tag)))
}

skill checker_block(block, scope, globals, diagnostics) {
    @plain = checker_plain(block)
    @index = 1
    @count = core.group.count(plain)
    drum (count) {
        (index < count) { diagnostics = checker_statement(core.group.item(plain, index), scope, globals, diagnostics) }
        index = index + 1
    }
    out diagnostics
}

skill checker_params(params, globals, subject, body, diagnostics) {
    @scope = CheckScope { subject = subject }
    (core.str.len(subject) > 0) {
        @model = checker_find(globals, subject)
        @member_index = 2
        @member_count = core.group.count(checker_plain(model.node))
        drum (member_count) {
            (member_index < member_count) {
                @member = checker_part(model.node, member_index)
                (checker_tag(member) == "field") { scope.names = checker_put(scope.names, checker_part(member, 1), "field", checker_type(checker_part(member, 2))) }
                member_index = member_index + 1
            }
        }
    }
    @index = 0
    @count = core.group.count(params)
    drum (count) {
        @name = core.group.item(params, index)
        (checker_has(scope.names, name) == yes) { diagnostics = checker_add(diagnostics, CheckDiagnostic { code = "duplicate_definition" message = core.str.add("duplicate parameter '", core.str.add(name, "'")) }) }
        (checker_has(scope.names, name) == no) { scope.names = checker_put(scope.names, name, "parameter", "unknown") }
        index = index + 1
    }
    out checker_block(body, scope, globals, diagnostics)
}

skill checker_check(ast) {
    @result = checker_collect(ast)
    @index = 1
    @count = core.group.count(ast)
    drum (count) {
        (index < count) {
            @item = core.group.item(ast, index)
            @tag = checker_tag(item)
            (tag == "const") { result.diagnostics = checker_expression(checker_part(item, 2), CheckScope {}, result.globals, result.diagnostics) }
            (tag == "skill") { result.diagnostics = checker_params(checker_part(item, 2), result.globals, "", checker_part(item, 3), result.diagnostics) }
            (tag == "entry") { result.diagnostics = checker_params(checker_part(item, 1), result.globals, "", checker_part(item, 2), result.diagnostics) }
            (tag == "box") {
                @seen_fields = []
                @seen_skills = []
                @member_index = 2
                @member_count = core.group.count(checker_plain(item))
                drum (member_count) {
                    (member_index < member_count) {
                        @member = checker_part(item, member_index)
                        @member_tag = checker_tag(member)
                        (member_tag == "field") {
                            @field_name = checker_part(member, 1)
                            (checker_has(seen_fields, field_name) == yes) {
                                @message = core.str.add("duplicate field '", field_name)
                                message = core.str.add(message, "' in Box '")
                                message = core.str.add(message, checker_part(item, 1))
                                message = core.str.add(message, "'")
                                result.diagnostics = checker_add(result.diagnostics, CheckDiagnostic { code = "duplicate_definition" message = message })
                            }
                            seen_fields = checker_put(seen_fields, field_name, "field", "unknown")
                            result.diagnostics = checker_expression(checker_part(member, 2), CheckScope {}, result.globals, result.diagnostics)
                        }
                        (member_tag == "subject-skill") {
                            @skill_name = checker_part(member, 1)
                            (checker_has(seen_skills, skill_name) == yes) {
                                @message = core.str.add("duplicate skill '", skill_name)
                                message = core.str.add(message, "' in Box '")
                                message = core.str.add(message, checker_part(item, 1))
                                message = core.str.add(message, "'")
                                result.diagnostics = checker_add(result.diagnostics, CheckDiagnostic { code = "duplicate_definition" message = message })
                            }
                            seen_skills = checker_put(seen_skills, skill_name, "skill", "function")
                            result.diagnostics = checker_params(checker_part(member, 2), result.globals, checker_part(item, 1), checker_part(member, 3), result.diagnostics)
                        }
                        member_index = member_index + 1
                    }
                }
            }
            index = index + 1
        }
    }
    out result
}

program() {
    core.io.show("библиотека чекера")
    out none
}
