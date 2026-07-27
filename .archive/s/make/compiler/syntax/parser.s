use core
use ast
use s.make.compiler.diagnostic

ParserIn = Box {
    source = ""
    path = ""
    tokens = []
}

ParserOut = Box {
    ast = none
    diagnostics = []
    path = ""
}

ParserContract = Box {
    input = ParserIn {}
    output = ParserOut {}
}

CallRead = Box {
    expression = none
    next = 0
}

skill s_compiler_parser_contract() {
    out ParserContract {}
}

skill s_compiler_parser_stub(in) {
    out ParserOut {
        ast = none
        diagnostics = []
        path = in.path
    }
}

skill parser_diagnostic(code, message, path) {
    out compiler_diagnostic(code, message, path, 0, 0)
}

skill parser_expression(token) {
    @result = ast_literal(token.kind, token.value)
    (token.kind == "IDENT") {
        result = ast_path(token.value)
    }
    out ast_with_location(result, token.line, token.col)
}

skill parser_binary_name(kind) {
    (kind == "PLUS") { out "core.num.add" }
    (kind == "MINUS") { out "core.num.sub" }
    (kind == "STAR") { out "core.num.mul" }
    (kind == "SLASH") { out "core.num.div" }
    (kind == "GT") { out "core.num.gt" }
    (kind == "LT") { out "core.num.lt" }
    (kind == "EQ") { out "core.num.eq" }
    out ""
}

skill parser_is_compare(kind) {
    (kind == "GT") { out yes }
    (kind == "LT") { out yes }
    (kind == "EQ") { out yes }
    out no
}

skill parser_binary(left, operator, right) {
    @args = core.group.add([], parser_expression(left))
    args = core.group.add(args, parser_expression(right))
    out ast_with_location(ast_call(parser_binary_name(operator.kind), args), left.line, left.col)
}

skill parser_read_group(tokens, start, end) {
    @items = []
    @cursor = start + 1
    @done = no
    @steps = end - start
    drum (steps) {
        (done == no) {
            @token = core.group.item(tokens, cursor)
            (token.kind == "RBRACKET") {
                cursor = cursor + 1
                done = yes
            }
            (done == no) {
                @item_expression = parser_expression(token)
                @item_next = cursor + 1
                (token.kind == "LBRACKET") {
                    @nested = parser_read_group(tokens, cursor, end)
                    item_expression = nested.expression
                    item_next = nested.next
                }
                (token.kind == "IDENT") {
                    @item_part = core.group.item(tokens, cursor + 1)
                    (item_part.kind == "LBRACE") {
                        @box = parser_read_box(tokens, cursor, end)
                        item_expression = box.expression
                        item_next = box.next
                    }
                }
                items = core.group.add(items, item_expression)
                @separator = core.group.item(tokens, item_next)
                (separator.kind == "COMMA") {
                    cursor = item_next + 1
                }
                (separator.kind == "RBRACKET") {
                    cursor = item_next + 1
                    done = yes
                }
            }
        }
    }
    out CallRead {
        expression = ast_group(items)
        next = cursor
    }
}

skill parser_read_box_fields(tokens, start, end) {
    @fields = []
    @cursor = start
    @steps = end - start
    drum (steps) {
        (cursor < end) {
            @name = core.group.item(tokens, cursor)
            (name.kind == "IDENT") {
                @eq = core.group.item(tokens, cursor + 1)
                (eq.kind == "ASSIGN") {
                    @value = core.group.item(tokens, cursor + 2)
                    @field_expression = parser_expression(value)
                    @field_next = cursor + 3
                    (value.kind == "LBRACKET") {
                        @group = parser_read_group(tokens, cursor + 2, end)
                        field_expression = group.expression
                        field_next = group.next
                    }
                    fields = core.group.add(fields, ast_assign(name.value, field_expression))
                    cursor = field_next
                    (cursor < end) {
                        @separator = core.group.item(tokens, cursor)
                        (separator.kind == "COMMA") {
                            cursor = cursor + 1
                        }
                    }
                }
            }
            (name.kind == "IDENT") {
            }
            (name.kind == "COMMA") {
                cursor = cursor + 1
            }
        }
    }
    out fields
}

skill parser_read_box(tokens, start, end) {
    @name = core.group.item(tokens, start)
    @close = parser_find_kind(tokens, start + 2, end, "RBRACE")
    @fields = parser_read_box_fields(tokens, start + 2, close)
    out CallRead {
        expression = ast_box_value(name.value, fields)
        next = close + 1
    }
}

skill parser_parse_box_decl(tokens, start, end) {
    @name = core.group.item(tokens, start)
    @close = parser_find_kind(tokens, start + 4, end, "RBRACE")
    @fields = parser_read_box_fields(tokens, start + 4, close)
    out ParserOut {
        ast = ast_box_decl(name.value, fields)
        diagnostics = []
        path = ""
    }
}

skill parser_slice(tokens, start, amount) {
    @result = []
    @index = start
    @steps = amount
    drum (steps) {
        result = core.group.add(result, core.group.item(tokens, index))
        index = index + 1
    }
    out result
}

skill parser_find_kind(tokens, start, end, kind) {
    @index = start
    @found = end
    @steps = end - start

    drum (steps) {
        (index < end) {
            @token = core.group.item(tokens, index)
            (token.kind == kind) {
                found = index
            }
            (found == end) {
                index = index + 1
            }
        }
    }

    out found
}

skill parser_read_call(tokens, start, end) {
    @first = core.group.item(tokens, start)
    @name = first.value
    @cursor = start + 1
    @done = no
    @args = []
    @steps = end - start

    drum (steps) {
        (done == no) {
            @part = core.group.item(tokens, cursor)
            (part.kind == "DOT") {
                @piece = core.group.item(tokens, cursor + 1)
                name = core.str.add(name, ".")
                name = core.str.add(name, piece.value)
                cursor = cursor + 2
            }
            (part.kind == "LPAREN") {
                cursor = cursor + 1
                @args_done = no
                drum (steps) {
                    (args_done == no) {
                        @arg = core.group.item(tokens, cursor)
                        (arg.kind == "RPAREN") {
                            cursor = cursor + 1
                            args_done = yes
                            done = yes
                        }
                        (args_done == no) {
                            @arg_expression = parser_expression(arg)
                            @arg_size = 1
                            (arg.kind == "IDENT") {
                                @arg_part = core.group.item(tokens, cursor + 1)
                                (arg_part.kind == "DOT") {
                                    @field = core.group.item(tokens, cursor + 2)
                                    arg_expression = ast_field(parser_expression(arg), field.value)
                                    arg_size = 3
                                }
                            }
                            args = core.group.add(args, arg_expression)
                            @separator = core.group.item(tokens, cursor + arg_size)
                            (separator.kind == "COMMA") {
                                cursor = cursor + arg_size + 1
                            }
                            (separator.kind == "RPAREN") {
                                cursor = cursor + arg_size + 1
                                args_done = yes
                                done = yes
                            }
                        }
                    }
                }
            }
        }
    }

    out CallRead {
        expression = ast_with_location(ast_call(name, args), first.line, first.col)
        next = cursor
    }
}

skill parser_parse_skill(tokens, path) {
    @count = core.group.size(tokens)
    @kind = core.group.item(tokens, 0)
    @name = core.group.item(tokens, 1)
    @open = core.group.item(tokens, 2)
    @params = []
    @param_index = 3
    @body_open_index = 0
    @body_close_index = count - 1
    @done = no
    @steps = count

    drum (steps) {
        (done == no) {
            @token = core.group.item(tokens, param_index)
            (token.kind == "RPAREN") {
                body_open_index = param_index + 1
                done = yes
            }
            (token.kind == "IDENT") {
                params = core.group.add(params, token.value)
            }
            (done == no) {
                param_index = param_index + 1
            }
        }
    }

    @body = parser_collect_body(tokens, body_open_index + 1, body_close_index)
    out ParserOut {
        ast = ast_skill(name.value, params, body)
        diagnostics = []
        path = path
    }
}

skill parser_parse_module(tokens, path) {
    @count = core.group.size(tokens)
    @index = 0
    @program_index = 0
    @found = no

    drum (count) {
        (found == no) {
            @token = core.group.item(tokens, index)
            (token.kind == "PROGRAM") {
                program_index = index
                found = yes
            }
            (found == no) {
                index = index + 1
            }
        }
    }

    (found == yes) {
        @late_skill = parser_find_kind(tokens, program_index + 1, count, "SKILL")
        (late_skill < count) {
            out ParserOut {
                ast = none
                diagnostics = core.group.add([], parser_diagnostic("declaration_after_program", "declaration after program", path))
                path = path
            }
        }
        @program_tokens = parser_slice(tokens, program_index, count - program_index)
        @program_result = parser_parse_program(program_tokens, path)
        @items = []
        @box_index = 0
        @box_steps = program_index
        drum (box_steps) {
            (box_index < program_index) {
                @box_name = core.group.item(tokens, box_index)
                (box_name.kind == "IDENT") {
                    @box_eq = core.group.item(tokens, box_index + 1)
                    @box_kind = core.group.item(tokens, box_index + 2)
                    (box_eq.kind == "ASSIGN") {
                        (box_kind.kind == "BOX") {
                            @box_result = parser_parse_box_decl(tokens, box_index, program_index)
                            items = core.group.add(items, box_result.ast)
                            @box_close = parser_find_kind(tokens, box_index + 4, program_index, "RBRACE")
                            box_index = box_close
                        }
                    }
                }
                box_index = box_index + 1
            }
        }
        @skill_index = parser_find_kind(tokens, 0, program_index, "SKILL")
        @skill_steps = program_index

        drum (skill_steps) {
            (skill_index < program_index) {
                @next_skill = parser_find_kind(tokens, skill_index + 1, program_index, "SKILL")
                @skill_end = next_skill
                (next_skill == program_index) {
                    skill_end = program_index
                }
                @skill_tokens = parser_slice(tokens, skill_index, skill_end - skill_index)
                @skill_result = parser_parse_skill(skill_tokens, path)
                items = core.group.add(items, skill_result.ast)
                skill_index = skill_end
            }
        }

        out ParserOut {
            ast = ast_program_with_body(items, program_result.ast.body)
            diagnostics = []
            path = path
        }
    }

    out ParserOut {
        ast = none
            diagnostics = core.group.add([], parser_diagnostic("expected_program", "expected program", path))
        path = path
    }
}

skill parser_collect_body(tokens, start, end) {
    @cursor = start
    @items = []
    @steps = end - start

    drum (steps) {
        (cursor < end) {
            @token = core.group.item(tokens, cursor)
            @handled = no
            (token.kind == "DRUM") {
                @count_token = core.group.item(tokens, cursor + 2)
                @body_open = core.group.item(tokens, cursor + 3)
                (body_open.kind == "LBRACE") {
                    @body_close = parser_find_kind(tokens, cursor + 4, end, "RBRACE")
                    @count_expression = parser_expression(count_token)
                    @block = parser_collect_body(tokens, cursor + 4, body_close)
                    items = core.group.add(items, ast_drum(count_expression, block))
                    cursor = body_close + 1
                    handled = yes
                }
            }
            (token.kind == "LPAREN") {
                @previous = core.group.item(tokens, cursor - 1)
                (previous.kind == "DRUM") {
                    @count_token = core.group.item(tokens, cursor + 1)
                    @body_open = core.group.item(tokens, cursor + 3)
                    (body_open.kind == "LBRACE") {
                        @body_close = parser_find_kind(tokens, cursor + 4, end, "RBRACE")
                        @count_expression = parser_expression(count_token)
                        @block = parser_collect_body(tokens, cursor + 4, body_close)
                        items = core.group.add(items, ast_drum(count_expression, block))
                        cursor = body_close + 1
                        handled = yes
                    }
                }
              (handled == no) {
                @test = core.group.item(tokens, cursor + 1)
                @body_open = core.group.item(tokens, cursor + 3)
                @operator = core.group.item(tokens, cursor + 2)
                (parser_is_compare(operator.kind) == yes) {
                    @right = core.group.item(tokens, cursor + 3)
                    body_open = core.group.item(tokens, cursor + 5)
                    (body_open.kind == "LBRACE") {
                        @body_close = parser_find_kind(tokens, cursor + 6, end, "RBRACE")
                        @test_expression = parser_binary(test, operator, right)
                        @block = parser_collect_body(tokens, cursor + 6, body_close)
                        items = core.group.add(items, ast_if(test_expression, block))
                        cursor = body_close + 1
                        handled = yes
                    }
                }
                (handled == no) {
                    (body_open.kind == "LBRACE") {
                        @body_close = parser_find_kind(tokens, cursor + 4, end, "RBRACE")
                        @test_expression = parser_expression(test)
                        @block = parser_collect_body(tokens, cursor + 4, body_close)
                        items = core.group.add(items, ast_if(test_expression, block))
                        cursor = body_close + 1
                        handled = yes
                    }
                }
              }
            }
            (token.kind == "AT") {
                @name = core.group.item(tokens, cursor + 1)
                @eq = core.group.item(tokens, cursor + 2)
                @value = core.group.item(tokens, cursor + 3)
                (eq.kind == "ASSIGN") {
                    @assign_expression = parser_expression(value)
                    (value.kind == "LBRACKET") {
                        @group = parser_read_group(tokens, cursor + 3, end)
                        assign_expression = group.expression
                        cursor = group.next - 4
                    }
                    (value.kind == "IDENT") {
                        (cursor + 4 < end) {
                            @call_part = core.group.item(tokens, cursor + 4)
                            (call_part.kind == "LBRACE") {
                                @box = parser_read_box(tokens, cursor + 3, end)
                                assign_expression = box.expression
                                cursor = box.next - 4
                            }
                            (call_part.kind == "DOT") {
                                @after_field = core.group.item(tokens, cursor + 6)
                                (after_field.kind == "DOT") {
                                    @call = parser_read_call(tokens, cursor + 3, end)
                                    assign_expression = call.expression
                                    cursor = call.next - 4
                                }
                                (after_field.kind == "LPAREN") {
                                    @call = parser_read_call(tokens, cursor + 3, end)
                                    assign_expression = call.expression
                                    cursor = call.next - 4
                                }
                                (after_field.kind == "DOT") {
                                }
                                (after_field.kind == "LPAREN") {
                                }
                                (after_field.kind == "RBRACE") {
                                    @field = core.group.item(tokens, cursor + 5)
                                    assign_expression = ast_field(parser_expression(value), field.value)
                                    cursor = cursor + 2
                                }
                            }
                            (call_part.kind == "LPAREN") {
                                @call = parser_read_call(tokens, cursor + 3, end)
                                assign_expression = call.expression
                                cursor = call.next - 4
                            }
                            (parser_binary_name(call_part.kind) == "core.num.add") {
                                @right = core.group.item(tokens, cursor + 5)
                                assign_expression = parser_binary(value, call_part, right)
                                cursor = cursor + 2
                            }
                            (parser_binary_name(call_part.kind) == "core.num.sub") {
                                @right = core.group.item(tokens, cursor + 5)
                                assign_expression = parser_binary(value, call_part, right)
                                cursor = cursor + 2
                            }
                            (parser_binary_name(call_part.kind) == "core.num.mul") {
                                @right = core.group.item(tokens, cursor + 5)
                                assign_expression = parser_binary(value, call_part, right)
                                cursor = cursor + 2
                            }
                            (parser_binary_name(call_part.kind) == "core.num.div") {
                                @right = core.group.item(tokens, cursor + 5)
                                assign_expression = parser_binary(value, call_part, right)
                                cursor = cursor + 2
                            }
                        }
                    }
                    items = core.group.add(items, ast_assign(name.value, assign_expression))
                    cursor = cursor + 4
                    handled = yes
                }
            }
            (token.kind == "IDENT") {
                (cursor + 1 < end) {
                    @eq = core.group.item(tokens, cursor + 1)
                    (eq.kind == "DOT") {
                        @field = core.group.item(tokens, cursor + 2)
                        @field_eq = core.group.item(tokens, cursor + 3)
                        (field_eq.kind == "ASSIGN") {
                            @field_value = core.group.item(tokens, cursor + 4)
                            @field_expression = parser_expression(field_value)
                            @field_next = cursor + 5
                            (field_value.kind == "LBRACKET") {
                                @group = parser_read_group(tokens, cursor + 4, end)
                                field_expression = group.expression
                                field_next = group.next
                            }
                            items = core.group.add(items, ast_field_set(parser_expression(token), field.value, field_expression))
                            cursor = field_next
                            handled = yes
                        }
                    }
                    (eq.kind == "ASSIGN") {
                        @value = core.group.item(tokens, cursor + 2)
                        @assign_expression = parser_expression(value)
                        (cursor + 3 < end) {
                            @operator = core.group.item(tokens, cursor + 3)
                            @binary_name = parser_binary_name(operator.kind)
                            (binary_name == "core.num.add") {
                                @right = core.group.item(tokens, cursor + 4)
                                assign_expression = parser_binary(value, operator, right)
                                cursor = cursor + 2
                            }
                            (binary_name == "core.num.sub") {
                                @right = core.group.item(tokens, cursor + 4)
                                assign_expression = parser_binary(value, operator, right)
                                cursor = cursor + 2
                            }
                            (binary_name == "core.num.mul") {
                                @right = core.group.item(tokens, cursor + 4)
                                assign_expression = parser_binary(value, operator, right)
                                cursor = cursor + 2
                            }
                            (binary_name == "core.num.div") {
                                @right = core.group.item(tokens, cursor + 4)
                                assign_expression = parser_binary(value, operator, right)
                                cursor = cursor + 2
                            }
                        }
                        items = core.group.add(items, ast_assign(token.value, assign_expression))
                        cursor = cursor + 3
                        handled = yes
                    }
                }
            }
            (token.kind == "OUT") {
                @value = core.group.item(tokens, cursor + 1)
                @out_expression = parser_expression(value)
                (value.kind == "IDENT") {
                    (cursor + 2 < end) {
                        @call_part = core.group.item(tokens, cursor + 2)
                        (call_part.kind == "LBRACE") {
                            @box = parser_read_box(tokens, cursor + 1, end)
                            out_expression = box.expression
                            cursor = box.next - 2
                        }
                        (call_part.kind == "DOT") {
                            @field = core.group.item(tokens, cursor + 3)
                            @after_field = core.group.item(tokens, cursor + 4)
                            (after_field.kind == "DOT") {
                                @call = parser_read_call(tokens, cursor + 1, end)
                                out_expression = call.expression
                                cursor = call.next - 2
                            }
                            (after_field.kind == "LPAREN") {
                                @call = parser_read_call(tokens, cursor + 1, end)
                                out_expression = call.expression
                                cursor = call.next - 2
                            }
                            (after_field.kind == "RBRACE") {
                                out_expression = ast_field(parser_expression(value), field.value)
                                cursor = cursor + 2
                            }
                        }
                        (call_part.kind == "LPAREN") {
                            @call = parser_read_call(tokens, cursor + 1, end)
                            out_expression = call.expression
                            cursor = call.next - 2
                        }
                        (parser_binary_name(call_part.kind) == "core.num.add") {
                            @right = core.group.item(tokens, cursor + 3)
                            out_expression = parser_binary(value, call_part, right)
                            cursor = cursor + 2
                        }
                        (parser_binary_name(call_part.kind) == "core.num.sub") {
                            @right = core.group.item(tokens, cursor + 3)
                            out_expression = parser_binary(value, call_part, right)
                            cursor = cursor + 2
                        }
                        (parser_binary_name(call_part.kind) == "core.num.mul") {
                            @right = core.group.item(tokens, cursor + 3)
                            out_expression = parser_binary(value, call_part, right)
                            cursor = cursor + 2
                        }
                        (parser_binary_name(call_part.kind) == "core.num.div") {
                            @right = core.group.item(tokens, cursor + 3)
                            out_expression = parser_binary(value, call_part, right)
                            cursor = cursor + 2
                        }
                    }
                }
                items = core.group.add(items, ast_out(out_expression))
                cursor = cursor + 2
                handled = yes
            }
            (handled == no) {
                cursor = cursor + 1
            }
        }
    }

    out items
}

skill parser_parse_program(tokens, path) {
    @count = core.group.size(tokens)
    (count == 0) {
        out ParserOut {
            ast = none
            diagnostics = core.group.add([], parser_diagnostic("expected_program_token", "expected program token", path))
            path = path
        }
    }

    @first = core.group.item(tokens, 0)
    (count < 7) {
        out ParserOut {
            ast = none
            diagnostics = core.group.add([], parser_diagnostic("incomplete_program", "incomplete program", path))
            path = path
        }
    }

    @open = core.group.item(tokens, 1)
    @close = core.group.item(tokens, 2)
    @body_open = core.group.item(tokens, 3)
    @last = core.group.item(tokens, count - 1)
    @body_first = core.group.item(tokens, 4)
    @body_value = core.group.item(tokens, 5)
    (first.kind == "PROGRAM") {
      (open.kind == "LPAREN") {
        (close.kind == "RPAREN") {
          (body_open.kind == "LBRACE") {
            (last.kind == "RBRACE") {
                @body = parser_collect_body(tokens, 4, count - 1)
                out ParserOut {
                    ast = ast_program_with_body(tokens, body)
                    diagnostics = []
                    path = path
                }
            }
          }
        }
      }
    }
    out ParserOut {
        ast = none
        diagnostics = core.group.add([], parser_diagnostic("expected_program", "expected program", path))
        path = path
    }
}
