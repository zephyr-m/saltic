use core

Diagnostic = Box {
    code = ""
    message = ""
    path = ""
    line = 0
    col = 0
}
skill compiler_diagnostic(code, message, path, line, col) {
    out Diagnostic {
        code = code
        message = message
        path = path
        line = line
        col = col
    }
}

TokenIn = Box {
    source = ""
    path = ""
    mode = "scan"
}

TokenOut = Box {
    tokens = []
    source = ""
    path = ""
    next = 0
}

Token = Box {
    kind = ""
    value = ""
    line = 1
    col = 1
}

TokenContract = Box {
    input = TokenIn {}
    output = TokenOut {}
}

skill s_compiler_token_contract() {
    out TokenContract {}
}

skill s_compiler_token_stub(in) {
    out TokenOut {
        tokens = []
        source = in.source
        path = in.path
    }
}

skill token_make(kind, value, line, col) {
    out Token {
        kind = kind
        value = value
        line = line
        col = col
    }
}

ScannerIn = Box {
    source = ""
    path = ""
}

ScannerOut = Box {
    tokens = []
    diagnostics = []
    path = ""
}

ScannerContract = Box {
    input = ScannerIn {}
    output = ScannerOut {}
}

skill s_compiler_scanner_contract() {
    out ScannerContract {}
}

skill s_compiler_scanner_stub(in) {
    out ScannerOut {
        tokens = []
        diagnostics = []
        path = in.path
    }
}

skill scanner_diagnostic(code, message, path, line, col) {
    out compiler_diagnostic(code, message, path, line, col)
}

skill scanner_is_letter(ch) {
    out core.str.contains("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_", ch)
}

skill scanner_is_digit(ch) {
    out core.str.contains("0123456789", ch)
}

skill scanner_word_kind(word) {
    (word == "program") { out "PROGRAM" }
    (word == "skill") { out "SKILL" }
    (word == "use") { out "USE" }
    (word == "Box") { out "BOX" }
    (word == "enum") { out "ENUM" }
    (word == "out") { out "OUT" }
    (word == "drum") { out "DRUM" }
    (word == "rescue") { out "RESCUE" }
    (word == "yes") { out "YES" }
    (word == "no") { out "NO" }
    (word == "none") { out "NONE" }
    out "IDENT"
}

skill scanner_read_word(source, start, line, col) {
    @index = start
    @length = core.str.len(source)
    @word = ""
    @done = no

    drum (length) {
        (index < length) {
            @ch = core.str.at(source, index)
            (done == no) {
              (scanner_is_letter(ch) == yes) {
                word = core.str.add(word, ch)
                index = index + 1
              }
              (scanner_is_digit(ch) == yes) {
                word = core.str.add(word, ch)
                index = index + 1
              }
              (scanner_is_letter(ch) == no) {
                (scanner_is_digit(ch) == no) {
                    done = yes
                }
              }
            }
        }
    }

    out TokenOut {
        tokens = core.group.add([], token_make(scanner_word_kind(word), word, line, col))
        source = source
        path = ""
        next = index
    }
}

skill scanner_is_space(ch) {
    (ch == " ") { out yes }
    (ch == "\t") { out yes }
    (ch == "\n") { out yes }
    out no
}

skill scanner_skip_space(source, start) {
    @index = start
    @length = core.str.len(source)

    drum (length) {
        (index < length) {
            @ch = core.str.at(source, index)
            (scanner_is_space(ch) == yes) {
                index = index + 1
            }
        }
    }

    out index
}

skill scanner_read_number(source, start, line, col) {
    @index = start
    @length = core.str.len(source)
    @value = ""
    @done = no

    drum (length) {
        (index < length) {
            @ch = core.str.at(source, index)
            (done == no) {
              (scanner_is_digit(ch) == yes) {
                value = core.str.add(value, ch)
                index = index + 1
              }
              (scanner_is_digit(ch) == no) {
                done = yes
              }
            }
        }
    }

    out TokenOut {
        tokens = core.group.add([], token_make("NUMBER", value, line, col))
        source = source
        path = ""
        next = index
    }
}

skill scanner_symbol_kind(ch) {
    (ch == "@") { out "AT" }
    (ch == "(") { out "LPAREN" }
    (ch == ")") { out "RPAREN" }
    (ch == "{") { out "LBRACE" }
    (ch == "}") { out "RBRACE" }
    (ch == "[") { out "LBRACKET" }
    (ch == "]") { out "RBRACKET" }
    (ch == "=") { out "ASSIGN" }
    (ch == "+") { out "PLUS" }
    (ch == "-") { out "MINUS" }
    (ch == "*") { out "STAR" }
    (ch == "/") { out "SLASH" }
    (ch == ">") { out "GT" }
    (ch == "<") { out "LT" }
    (ch == ".") { out "DOT" }
    (ch == ",") { out "COMMA" }
    out "UNKNOWN"
}

skill scanner_read_string(source, start, line, col) {
    @index = start + 1
    @length = core.str.len(source)
    @value = ""
    @closed = no
    @escaped = no

    drum (length) {
        (index < length) {
            @ch = core.str.at(source, index)
            @ordinary = yes
            (closed == no) {
                @was_escaped = escaped
                (was_escaped == yes) {
                    @decoded = ch
                    (ch == "n") { decoded = "\n" }
                    (ch == "t") { decoded = "\t" }
                    (ch == "\"") { decoded = "\"" }
                    (ch == "\\") { decoded = "\\" }
                    value = core.str.add(value, decoded)
                    escaped = no
                    index = index + 1
                    ordinary = no
                }
                (was_escaped == no) {
                    (ch == "\\") {
                        escaped = yes
                        index = index + 1
                        ordinary = no
                    }
                    (ch == "\"") {
                        closed = yes
                        index = index + 1
                        ordinary = no
                    }
                    (ch == "\n") {
                        closed = yes
                        ordinary = no
                    }
                }
                (ordinary == yes) {
                    value = core.str.add(value, ch)
                    index = index + 1
                }
            }
        }
    }

    @kind = "STRING"
    (closed == no) {
        kind = "ERROR_UNTERMINATED_STRING"
    }

    out TokenOut {
        tokens = core.group.add([], token_make(kind, value, line, col))
        source = source
        path = ""
        next = index
    }
}

skill scanner_two_symbol_kind(first, second) {
    (first == "=") {
        (second == "=") { out "EQ" }
        (second == ">") { out "ARROW" }
    }
    out "UNKNOWN"
}

skill scanner_read_symbol(source, start, line, col) {
    @ch = core.str.at(source, start)
    out TokenOut {
        tokens = core.group.add([], token_make(scanner_symbol_kind(ch), ch, line, col))
        source = source
        path = ""
        next = start + 1
    }
}

skill scanner_skip_comment(source, start) {
    @index = start + 2
    @length = core.str.len(source)
    @done = no

    drum (length) {
        (index < length) {
            @ch = core.str.at(source, index)
            (done == no) {
                (ch == "\n") {
                    done = yes
                }
                (done == no) {
                    index = index + 1
                }
            }
        }
    }

    out index
}

skill scanner_scan(source, path) {
    @tokens = []
    @index = 0
    @line = 1
    @col = 1
    @diagnostics = []
    @length = core.str.len(source)

    drum (length) {
        (index < length) {
            @ch = core.str.at(source, index)
            @handled = no
            (ch == "/") {
                (index + 1 < length) {
                    @next_ch = core.str.at(source, index + 1)
                    (next_ch == "/") {
                        index = scanner_skip_comment(source, index)
                        handled = yes
                    }
                }
            }
            (scanner_is_space(ch) == yes) {
                col = col + 1
                (ch == "\n") {
                    line = line + 1
                    col = 1
                }
                index = index + 1
                handled = yes
            }
            (scanner_is_space(ch) == no) {
              (handled == no) {
              (ch == "\"") {
                    @tail = core.str.slice(source, index + 1, length)
                    (core.str.contains(tail, "\"") == no) {
                        tokens = core.group.add(tokens, token_make("ERROR_UNTERMINATED_STRING", tail, line, col))
                        diagnostics = core.group.add(diagnostics, scanner_diagnostic("unterminated_string", "unterminated string", path, line, col))
                        index = length
                        handled = yes
                    }
                    (handled == no) {
                        @string = scanner_read_string(source, index, line, col)
                        @token = core.group.item(string.tokens, 0)
                        tokens = core.group.add(tokens, token)
                        @width = string.next - index
                        index = string.next
                        col = col + width
                        handled = yes
                    }
              }
              (handled == no) {
                (scanner_is_letter(ch) == yes) {
                    @word = scanner_read_word(source, index, line, col)
                    @token = core.group.item(word.tokens, 0)
                    tokens = core.group.add(tokens, token)
                    @width = word.next - index
                    index = word.next
                    col = col + width
                    handled = yes
                }
                (scanner_is_letter(ch) == no) {
                    (ch == "=") {
                        (index + 1 < length) {
                            @next_ch = core.str.at(source, index + 1)
                            @two_kind = scanner_two_symbol_kind(ch, next_ch)
                            (two_kind == "UNKNOWN") {
                                @symbol = scanner_read_symbol(source, index, line, col)
                                @token = core.group.item(symbol.tokens, 0)
                                tokens = core.group.add(tokens, token)
                                index = symbol.next
                            }
                            (two_kind == "EQ") {
                                tokens = core.group.add(tokens, token_make(two_kind, core.str.add(ch, next_ch), line, col))
                                index = index + 2
                            }
                            (two_kind == "ARROW") {
                                tokens = core.group.add(tokens, token_make(two_kind, core.str.add(ch, next_ch), line, col))
                                index = index + 2
                            }
                            handled = yes
                        }
                    }
                    (scanner_is_digit(ch) == yes) {
                        @number = scanner_read_number(source, index, line, col)
                        @token = core.group.item(number.tokens, 0)
                        tokens = core.group.add(tokens, token)
                        @width = number.next - index
                        index = number.next
                        col = col + width
                    }
                    (scanner_is_digit(ch) == no) {
                      (handled == no) {
                        @symbol = scanner_read_symbol(source, index, line, col)
                        @token = core.group.item(symbol.tokens, 0)
                        tokens = core.group.add(tokens, token)
                        (token.kind == "UNKNOWN") {
                            (core.str.len(ch) > 0) {
                            diagnostics = core.group.add(diagnostics, scanner_diagnostic("unknown_symbol", "unknown symbol", path, line, col))
                            }
                        }
                        index = symbol.next
                        col = col + 1
                      }
                    }
                }
              }
              }
            }
        }
    }

    out ScannerOut {
        tokens = tokens
        diagnostics = diagnostics
        path = path
    }
}

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
