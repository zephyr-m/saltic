use core

SalticToken = Box {
    kind = ""
    value = ""
    line = 1
    col = 1
}

SalticScan = Box {
    tokens = []
    diagnostics = []
}

SalticNode = Box {
    datum = []
    tag = ""
}

SalticRead = Box {
    node = SalticNode {}
    next = 0
    diagnostics = []
}

SalticParse = Box {
    ast = []
    tokens = []
    diagnostics = []
}

SalticLoad = Box {
    ast = []
    included = []
    diagnostics = []
}

skill parser_group1(a) {
    out core.group.add([], a)
}

skill parser_group2(a, b) {
    out core.group.add(parser_group1(a), b)
}

skill parser_group3(a, b, c) {
    out core.group.add(parser_group2(a, b), c)
}

skill parser_group4(a, b, c, d) {
    out core.group.add(parser_group3(a, b, c), d)
}

skill parser_token(kind, value, line, col) {
    out SalticToken { kind = kind value = value line = line col = col }
}

skill parser_diagnostic(path, line, col, message) {
    @where = core.str.add(path, ":")
    where = core.str.add(where, core_num_text(line))
    where = core.str.add(where, ":")
    where = core.str.add(where, core_num_text(col))
    where = core.str.add(where, ": ")
    out core.str.add(where, message)
}

skill parser_has_diagnostics(diagnostics) {
    out core.group.count(diagnostics) > 0
}

skill parser_is_digit(ch) {
    out core.str.contains("0123456789", ch)
}

skill parser_digit_value(ch) {
    (ch == "0") { out 0 }
    (ch == "1") { out 1 }
    (ch == "2") { out 2 }
    (ch == "3") { out 3 }
    (ch == "4") { out 4 }
    (ch == "5") { out 5 }
    (ch == "6") { out 6 }
    (ch == "7") { out 7 }
    (ch == "8") { out 8 }
    out 9
}

skill parser_number_value(text) {
    @whole = 0
    @fraction = 0
    @scale = 1
    @after_dot = no
    @index = 0
    @length = core.str.len(text)
    drum (length) {
        (index < length) {
            @ch = core.str.at(text, index)
            (ch == ".") { after_dot = yes }
            (parser_is_digit(ch) == yes) {
                (after_dot == no) { whole = whole * 10 + parser_digit_value(ch) }
                (after_dot == yes) { fraction = fraction * 10 + parser_digit_value(ch) scale = scale * 10 }
            }
            index = index + 1
        }
    }
    out whole + fraction / scale
}

skill parser_is_ascii_letter(ch) {
    out core.str.contains("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", ch)
}

skill parser_is_ident_start(ch) {
    (parser_is_ascii_letter(ch) == yes) { out yes }
    (ch == "_") { out yes }
    @upper = core.str.upper(ch)
    @lower = core.str.lower(ch)
    (upper == lower) { out no }
    out yes
}

skill parser_is_ident_part(ch) {
    (parser_is_ident_start(ch) == yes) { out yes }
    out parser_is_digit(ch)
}

skill parser_word_kind(word) {
    (word == "skill") { out "SKILL" }
    (word == "program") { out "PROGRAM" }
    (word == "use") { out "USE" }
    (word == "Box") { out "BOX" }
    (word == "out") { out "OUT" }
    (word == "enum") { out "ENUM" }
    (word == "drum") { out "DRUM" }
    (word == "rescue") { out "RESCUE" }
    (word == "yes") { out "YES" }
    (word == "no") { out "NO" }
    (word == "none") { out "NONE" }
    out "IDENT"
}

skill parser_sign_kind(ch) {
    (ch == "@") { out "AT" }
    (ch == "{") { out "LBRACE" }
    (ch == "}") { out "RBRACE" }
    (ch == "[") { out "LBRACKET" }
    (ch == "]") { out "RBRACKET" }
    (ch == "(") { out "LPAREN" }
    (ch == ")") { out "RPAREN" }
    (ch == ",") { out "COMMA" }
    (ch == ".") { out "DOT" }
    (ch == "|") { out "PIPE" }
    (ch == "=") { out "ASSIGN" }
    (ch == ">") { out "GT" }
    (ch == "<") { out "LT" }
    (ch == "+") { out "PLUS" }
    (ch == "-") { out "MINUS" }
    (ch == "*") { out "STAR" }
    (ch == "/") { out "SLASH" }
    out ""
}

skill parser_lex(source, path) {
    @tokens = []
    @diagnostics = []
    @index = 0
    @line = 1
    @col = 1
    @length = core.str.len(source)
    @active = yes
    drum (length + 1) {
        (active == yes) {
            (index < length) {
                @ch = core.str.at(source, index)
                @handled = no
                (ch == " ") { index = index + 1 col = col + 1 handled = yes }
                (ch == "\t") { index = index + 1 col = col + 1 handled = yes }
                (ch == "\n") {
                    tokens = core.group.add(tokens, parser_token("NEWLINE", "\n", line, col))
                    index = index + 1
                    line = line + 1
                    col = 1
                    handled = yes
                }
                (handled == no) {
                    (parser_is_ident_start(ch) == yes) {
                        @start = index
                        @start_col = col
                        @reading = yes
                        drum (length) {
                            (reading == yes) {
                                (index < length) {
                                    @part = core.str.at(source, index)
                                    (parser_is_ident_part(part) == yes) { index = index + 1 col = col + 1 }
                                    (parser_is_ident_part(part) == no) { reading = no }
                                }
                                (index == length) { reading = no }
                            }
                        }
                        @word = core.str.slice(source, start, index)
                        tokens = core.group.add(tokens, parser_token(parser_word_kind(word), word, line, start_col))
                        handled = yes
                    }
                }
                (handled == no) {
                    (parser_is_digit(ch) == yes) {
                        @number_start = index
                        @number_col = col
                        @dot = no
                        @number_reading = yes
                        drum (length) {
                            (number_reading == yes) {
                                (index < length) {
                                    @digit = core.str.at(source, index)
                                    @take = parser_is_digit(digit)
                                    (digit == ".") {
                                        (dot == no) {
                                            (index + 1 < length) {
                                                (parser_is_digit(core.str.at(source, index + 1)) == yes) { take = yes dot = yes }
                                            }
                                        }
                                    }
                                    (take == yes) { index = index + 1 col = col + 1 }
                                    (take == no) { number_reading = no }
                                }
                                (index == length) { number_reading = no }
                            }
                        }
                        tokens = core.group.add(tokens, parser_token("NUMBER", core.str.slice(source, number_start, index), line, number_col))
                        handled = yes
                    }
                }
                (handled == no) {
                    (ch == "\"") {
                        @string_line = line
                        @string_col = col
                        @value = ""
                        @closed = no
                        index = index + 1
                        col = col + 1
                        drum (length) {
                            (closed == no) {
                                (index < length) {
                                    @string_ch = core.str.at(source, index)
                                    (string_ch == "\"") { closed = yes index = index + 1 col = col + 1 }
                                    (string_ch == "\\") {
                                        (closed == no) {
                                            (index + 1 < length) {
                                                @escape = core.str.at(source, index + 1)
                                                @decoded = escape
                                                (escape == "n") { decoded = "\n" }
                                                (escape == "t") { decoded = "\t" }
                                                (escape == "\"") { decoded = "\"" }
                                                (escape == "\\") { decoded = "\\" }
                                                value = core.str.add(value, decoded)
                                                index = index + 2
                                                col = col + 2
                                            }
                                            (index + 1 == length) {
                                                diagnostics = core.group.add(diagnostics, parser_diagnostic(path, line, col, "unterminated escape"))
                                                active = no
                                                closed = yes
                                            }
                                        }
                                    }
                                    (closed == no) {
                                        (string_ch == "\n") { value = core.str.add(value, string_ch) index = index + 1 line = line + 1 col = 1 }
                                        @ordinary = yes
                                        (string_ch == "\n") { ordinary = no }
                                        (string_ch == "\"") { ordinary = no }
                                        (string_ch == "\\") { ordinary = no }
                                        (ordinary == yes) { value = core.str.add(value, string_ch) index = index + 1 col = col + 1 }
                                    }
                                }
                                (closed == no) {
                                  (index == length) {
                                    diagnostics = core.group.add(diagnostics, parser_diagnostic(path, string_line, string_col, "unterminated string"))
                                    active = no
                                    closed = yes
                                  }
                                }
                            }
                        }
                        (parser_has_diagnostics(diagnostics) == no) {
                            tokens = core.group.add(tokens, parser_token("STRING", value, string_line, string_col))
                        }
                        handled = yes
                    }
                }
                (handled == no) {
                    @pair = ""
                    (index + 1 < length) { pair = core.str.slice(source, index, index + 2) }
                    (pair == "==") { tokens = core.group.add(tokens, parser_token("EQ", pair, line, col)) index = index + 2 col = col + 2 handled = yes }
                    (pair == "=>") { tokens = core.group.add(tokens, parser_token("ARROW", pair, line, col)) index = index + 2 col = col + 2 handled = yes }
                }
                (handled == no) {
                    @sign = parser_sign_kind(ch)
                    (sign == "") {
                        @message = core.str.add("unexpected character ", ch)
                        diagnostics = core.group.add(diagnostics, parser_diagnostic(path, line, col, message))
                        active = no
                    }
                    (sign == "") { }
                    (sign == "AT") { handled = yes }
                    (sign == "LBRACE") { handled = yes }
                    (sign == "RBRACE") { handled = yes }
                    (sign == "LBRACKET") { handled = yes }
                    (sign == "RBRACKET") { handled = yes }
                    (sign == "LPAREN") { handled = yes }
                    (sign == "RPAREN") { handled = yes }
                    (sign == "COMMA") { handled = yes }
                    (sign == "DOT") { handled = yes }
                    (sign == "PIPE") { handled = yes }
                    (sign == "ASSIGN") { handled = yes }
                    (sign == "GT") { handled = yes }
                    (sign == "LT") { handled = yes }
                    (sign == "PLUS") { handled = yes }
                    (sign == "MINUS") { handled = yes }
                    (sign == "STAR") { handled = yes }
                    (sign == "SLASH") { handled = yes }
                    (handled == yes) {
                        tokens = core.group.add(tokens, parser_token(sign, ch, line, col))
                        index = index + 1
                        col = col + 1
                    }
                }
            }
            (index == length) { active = no }
        }
    }
    tokens = core.group.add(tokens, parser_token("EOF", "", line, col))
    out SalticScan { tokens = tokens diagnostics = diagnostics }
}

skill parser_at(tokens, index) {
    out core.group.item(tokens, index)
}

skill parser_is(tokens, index, kind) {
    @token = parser_at(tokens, index)
    out token.kind == kind
}

skill parser_skip_lines(tokens, index) {
    @next = index
    @count = core.group.count(tokens)
    drum (count) {
        (next < count) {
            (parser_is(tokens, next, "NEWLINE") == yes) { next = next + 1 }
        }
    }
    out next
}

skill parser_loc(datum, token, locations) {
    (locations == yes) { out parser_group4("loc", token.line, token.col, datum) }
    out datum
}

skill parser_node(tag, datum) {
    out SalticNode { datum = datum tag = tag }
}

skill parser_ok(tag, datum, next) {
    out SalticRead { node = parser_node(tag, datum) next = next diagnostics = [] }
}

skill parser_fail(tokens, index, message, path) {
    @token = parser_at(tokens, index)
    @tail = core.str.add(message, ", got ")
    tail = core.str.add(tail, token.kind)
    out SalticRead {
        node = parser_node("", [])
        next = index
        diagnostics = parser_group1(parser_diagnostic(path, token.line, token.col, tail))
    }
}

skill parser_expect(tokens, index, kind, message, path) {
    @token = parser_at(tokens, index)
    (parser_is(tokens, index, kind) == yes) { out parser_ok("token", parser_group1(token.value), index + 1) }
    out parser_fail(tokens, index, message, path)
}

skill parser_append_tail(head, tail, start) {
    @result = head
    @cursor = start
    @count = core.group.count(tail)
    drum (count) {
        (cursor < count) { result = core.group.add(result, core.group.item(tail, cursor)) cursor = cursor + 1 }
    }
    out result
}

skill parser_path(tokens, start, path, locations) {
    (parser_is(tokens, start, "IDENT") == no) { out parser_fail(tokens, start, "expected identifier", path) }
    @token = parser_at(tokens, start)
    @parts = parser_group2("path", token.value)
    @next = start + 1
    @count = core.group.count(tokens)
    @active = yes
    drum (count) {
        (active == yes) {
            (next + 1 < count) {
                (parser_is(tokens, next, "DOT") == yes) {
                    (parser_is(tokens, next + 1, "IDENT") == yes) {
                        @part_token = parser_at(tokens, next + 1)
                        parts = core.group.add(parts, part_token.value)
                        next = next + 2
                    }
                    (parser_is(tokens, next + 1, "IDENT") == no) { active = no }
                }
                (parser_is(tokens, next, "DOT") == no) { active = no }
            }
            (next + 1 == count) { active = no }
        }
    }
    out parser_ok("path", parser_loc(parts, token, locations), next)
}

skill parser_params(tokens, start, path) {
    @params = []
    @next = start
    @done = parser_is(tokens, next, "RPAREN")
    @diagnostics = []
    @count = core.group.count(tokens)
    drum (count) {
        (done == no) {
            (parser_is(tokens, next, "IDENT") == no) {
                @failure = parser_fail(tokens, next, "expected parameter name", path)
                diagnostics = failure.diagnostics
                done = yes
            }
            (parser_has_diagnostics(diagnostics) == no) {
                @param_token = parser_at(tokens, next)
                params = core.group.add(params, param_token.value)
                next = next + 1
                @comma = parser_is(tokens, next, "COMMA")
                (comma == yes) { next = next + 1 }
                (comma == no) { done = yes }
            }
        }
    }
    out SalticRead { node = parser_node("params", params) next = next diagnostics = diagnostics }
}

skill parser_primary(tokens, start, path, locations) {
    @token = parser_at(tokens, start)
    (token.kind == "NUMBER") { out parser_ok("number", parser_loc(parser_group2("number", parser_number_value(token.value)), token, locations), start + 1) }
    (token.kind == "STRING") { out parser_ok("string", parser_loc(parser_group2("string", token.value), token, locations), start + 1) }
    (token.kind == "YES") { out parser_ok("answer", parser_loc(parser_group2("answer", "yes"), token, locations), start + 1) }
    (token.kind == "NO") { out parser_ok("answer", parser_loc(parser_group2("answer", "no"), token, locations), start + 1) }
    (token.kind == "NONE") { out parser_ok("none", parser_loc(parser_group1("none"), token, locations), start + 1) }
    (token.kind == "DOT") {
        (parser_is(tokens, start + 1, "IDENT") == no) { out parser_fail(tokens, start + 1, "expected enum value", path) }
        @name_token = parser_at(tokens, start + 1)
        out parser_ok("enum-value", parser_loc(parser_group2("enum-value", name_token.value), token, locations), start + 2)
    }
    (token.kind == "LBRACKET") { out parser_group(tokens, start, path, locations) }
    (token.kind == "IDENT") { out parser_path(tokens, start, path, locations) }
    (token.kind == "LPAREN") {
        @inside = parser_expression(tokens, start + 1, path, locations)
        (parser_has_diagnostics(inside.diagnostics) == yes) { out inside }
        @close = parser_expect(tokens, inside.next, "RPAREN", "expected RPAREN", path)
        (parser_has_diagnostics(close.diagnostics) == yes) { out close }
        out SalticRead { node = inside.node next = close.next diagnostics = [] }
    }
    out parser_fail(tokens, start, "expected expression", path)
}

skill parser_args(tokens, start, path, locations) {
    @args = []
    @next = start + 1
    @done = no
    @diagnostics = []
    (parser_is(tokens, next, "RPAREN") == yes) { next = next + 1 done = yes }
    @count = core.group.count(tokens)
    drum (count) {
        (done == no) {
            @arg = parser_expression(tokens, next, path, locations)
            (parser_has_diagnostics(arg.diagnostics) == yes) { diagnostics = arg.diagnostics done = yes }
            (parser_has_diagnostics(arg.diagnostics) == no) {
                args = core.group.add(args, arg.node.datum)
                next = arg.next
                @comma = parser_is(tokens, next, "COMMA")
                (comma == yes) { next = next + 1 }
                (comma == no) {
                    @close = parser_expect(tokens, next, "RPAREN", "expected RPAREN", path)
                    (parser_has_diagnostics(close.diagnostics) == yes) { diagnostics = close.diagnostics }
                    (parser_has_diagnostics(close.diagnostics) == no) { next = close.next }
                    done = yes
                }
            }
        }
    }
    out SalticRead { node = parser_node("args", args) next = next diagnostics = diagnostics }
}

skill parser_fields(tokens, start, path, locations) {
    @open = parser_expect(tokens, start, "LBRACE", "expected LBRACE", path)
    (parser_has_diagnostics(open.diagnostics) == yes) { out open }
    @fields = []
    @next = parser_skip_lines(tokens, open.next)
    @done = no
    @diagnostics = []
    @count = core.group.count(tokens)
    drum (count) {
        (done == no) {
            (parser_is(tokens, next, "RBRACE") == yes) { next = next + 1 done = yes }
            (done == no) {
              (parser_is(tokens, next, "EOF") == yes) { @failure = parser_fail(tokens, next, "expected }", path) diagnostics = failure.diagnostics done = yes }
            }
            (done == no) {
                (parser_is(tokens, next, "IDENT") == no) { @failure = parser_fail(tokens, next, "expected field name", path) diagnostics = failure.diagnostics done = yes }
                (done == no) {
                    @name_token = parser_at(tokens, next)
                    @name = name_token.value
                    @eq = parser_expect(tokens, next + 1, "ASSIGN", "expected = after field name", path)
                    (parser_has_diagnostics(eq.diagnostics) == yes) { diagnostics = eq.diagnostics done = yes }
                    (done == no) {
                        @value = parser_expression(tokens, eq.next, path, locations)
                        (parser_has_diagnostics(value.diagnostics) == yes) { diagnostics = value.diagnostics done = yes }
                        (done == no) {
                            fields = core.group.add(fields, parser_group3("field", name, value.node.datum))
                            next = value.next
                            (parser_is(tokens, next, "COMMA") == yes) { next = next + 1 }
                            next = parser_skip_lines(tokens, next)
                        }
                    }
                }
            }
        }
    }
    out SalticRead { node = parser_node("fields", fields) next = next diagnostics = diagnostics }
}

skill parser_postfix(tokens, start, path, locations) {
    @base = parser_primary(tokens, start, path, locations)
    (parser_has_diagnostics(base.diagnostics) == yes) { out base }
    @node = base.node
    @next = base.next
    @active = yes
    @diagnostics = []
    @count = core.group.count(tokens)
    drum (count) {
        (active == yes) {
            (parser_is(tokens, next, "LPAREN") == yes) {
                @call_token = parser_at(tokens, next)
                @args = parser_args(tokens, next, path, locations)
                (parser_has_diagnostics(args.diagnostics) == yes) { diagnostics = args.diagnostics active = no }
                (parser_has_diagnostics(args.diagnostics) == no) {
                    @call = parser_group2("call", node.datum)
                    call = parser_append_tail(call, args.node.datum, 0)
                    node = parser_node("call", parser_loc(call, call_token, locations))
                    next = args.next
                }
            }
            (parser_is(tokens, next, "LPAREN") == no) {
                @box_candidate = no
                (node.tag == "path") {
                    @plain_path = node.datum
                    (locations == yes) { plain_path = core.group.item(node.datum, 3) }
                    (core.group.count(plain_path) == 2) {
                        (parser_is(tokens, next, "LBRACE") == yes) { box_candidate = yes }
                    }
                }
                (box_candidate == yes) {
                    @box_token = parser_at(tokens, next)
                    @fields = parser_fields(tokens, next, path, locations)
                    (parser_has_diagnostics(fields.diagnostics) == yes) { diagnostics = fields.diagnostics active = no }
                    (parser_has_diagnostics(fields.diagnostics) == no) {
                        @plain_name = node.datum
                        (locations == yes) { plain_name = core.group.item(node.datum, 3) }
                        @box = parser_group2("box-new", core.group.item(plain_name, 1))
                        box = parser_append_tail(box, fields.node.datum, 0)
                        node = parser_node("box-new", parser_loc(box, box_token, locations))
                        next = fields.next
                    }
                }
                (box_candidate == no) { active = no }
            }
        }
    }
    out SalticRead { node = node next = next diagnostics = diagnostics }
}

skill parser_precedence(kind) {
    (kind == "EQ") { out 1 }
    (kind == "GT") { out 1 }
    (kind == "LT") { out 1 }
    (kind == "PLUS") { out 2 }
    (kind == "MINUS") { out 2 }
    (kind == "STAR") { out 3 }
    (kind == "SLASH") { out 3 }
    out 0
}

skill parser_binary(tokens, start, minimum, path, locations) {
    @first = parser_postfix(tokens, start, path, locations)
    (parser_has_diagnostics(first.diagnostics) == yes) { out first }
    @left = first.node
    @next = first.next
    @active = yes
    @diagnostics = []
    @count = core.group.count(tokens)
    drum (count) {
        (active == yes) {
            @operator = parser_at(tokens, next)
            @level = parser_precedence(operator.kind)
            (level < minimum) { active = no }
            (level == 0) { active = no }
            (active == yes) {
                @right = parser_binary(tokens, next + 1, level + 1, path, locations)
                (parser_has_diagnostics(right.diagnostics) == yes) { diagnostics = right.diagnostics active = no }
                (parser_has_diagnostics(right.diagnostics) == no) {
                    left = parser_node("binary", parser_loc(parser_group4("binary", operator.value, left.datum, right.node.datum), operator, locations))
                    next = right.next
                }
            }
        }
    }
    out SalticRead { node = left next = next diagnostics = diagnostics }
}

skill parser_expression(tokens, start, path, locations) {
    @value = parser_binary(tokens, start, 0, path, locations)
    (parser_has_diagnostics(value.diagnostics) == yes) { out value }
    (parser_is(tokens, value.next, "RESCUE") == yes) {
        @rescue_token = parser_at(tokens, value.next)
        @pipe = parser_expect(tokens, value.next + 1, "PIPE", "expected PIPE", path)
        (parser_has_diagnostics(pipe.diagnostics) == yes) { out pipe }
        (parser_is(tokens, pipe.next, "IDENT") == no) { out parser_fail(tokens, pipe.next, "expected rescue error name", path) }
        @error_token = parser_at(tokens, pipe.next)
        @error_name = error_token.value
        @pipe2 = parser_expect(tokens, pipe.next + 1, "PIPE", "expected PIPE", path)
        (parser_has_diagnostics(pipe2.diagnostics) == yes) { out pipe2 }
        @body = parser_block(tokens, pipe2.next, path, locations)
        (parser_has_diagnostics(body.diagnostics) == yes) { out body }
        out parser_ok("rescue", parser_loc(parser_group4("rescue", value.node.datum, error_name, body.node.datum), rescue_token, locations), body.next)
    }
    out value
}

skill parser_group(tokens, start, path, locations) {
    @token = parser_at(tokens, start)
    @items = parser_group1("group")
    @next = parser_skip_lines(tokens, start + 1)
    @done = no
    @diagnostics = []
    @count = core.group.count(tokens)
    drum (count) {
        (done == no) {
            (parser_is(tokens, next, "RBRACKET") == yes) { next = next + 1 done = yes }
            (done == no) {
              (parser_is(tokens, next, "EOF") == yes) { @failure = parser_fail(tokens, next, "expected ]", path) diagnostics = failure.diagnostics done = yes }
            }
            (done == no) {
                @item = parser_expression(tokens, next, path, locations)
                (parser_has_diagnostics(item.diagnostics) == yes) { diagnostics = item.diagnostics done = yes }
                (done == no) {
                    items = core.group.add(items, item.node.datum)
                    next = item.next
                    (parser_is(tokens, next, "COMMA") == yes) { next = next + 1 }
                    next = parser_skip_lines(tokens, next)
                }
            }
        }
    }
    out SalticRead { node = parser_node("group", parser_loc(items, token, locations)) next = next diagnostics = diagnostics }
}

skill parser_block(tokens, start, path, locations) {
    @token = parser_at(tokens, start)
    @open = parser_expect(tokens, start, "LBRACE", "expected LBRACE", path)
    (parser_has_diagnostics(open.diagnostics) == yes) { out open }
    @items = parser_group1("block")
    @next = parser_skip_lines(tokens, open.next)
    @done = no
    @diagnostics = []
    @count = core.group.count(tokens)
    drum (count) {
        (done == no) {
            (parser_is(tokens, next, "RBRACE") == yes) { next = next + 1 done = yes }
            (done == no) {
              (parser_is(tokens, next, "EOF") == yes) { @failure = parser_fail(tokens, next, "expected }", path) diagnostics = failure.diagnostics done = yes }
            }
            (done == no) {
                @statement = parser_statement(tokens, next, path, locations)
                (parser_has_diagnostics(statement.diagnostics) == yes) { diagnostics = statement.diagnostics done = yes }
                (done == no) {
                    items = core.group.add(items, statement.node.datum)
                    next = parser_skip_lines(tokens, statement.next)
                }
            }
        }
    }
    out SalticRead { node = parser_node("block", parser_loc(items, token, locations)) next = next diagnostics = diagnostics }
}

skill parser_var(tokens, start, path, locations) {
    @token = parser_at(tokens, start)
    (parser_is(tokens, start + 1, "IDENT") == no) { out parser_fail(tokens, start + 1, "expected variable name", path) }
    @name_token = parser_at(tokens, start + 1)
    @name = name_token.value
    @eq = parser_expect(tokens, start + 2, "ASSIGN", "expected = after variable name", path)
    (parser_has_diagnostics(eq.diagnostics) == yes) { out eq }
    @value = parser_expression(tokens, eq.next, path, locations)
    (parser_has_diagnostics(value.diagnostics) == yes) { out value }
    out parser_ok("var", parser_loc(parser_group3("var", name, value.node.datum), token, locations), value.next)
}

skill parser_assign(tokens, start, path, locations) {
    @token = parser_at(tokens, start)
    @value = parser_expression(tokens, start + 2, path, locations)
    (parser_has_diagnostics(value.diagnostics) == yes) { out value }
    out parser_ok("assign", parser_loc(parser_group3("assign", token.value, value.node.datum), token, locations), value.next)
}

skill parser_out(tokens, start, path, locations) {
    @token = parser_at(tokens, start)
    @value = parser_expression(tokens, start + 1, path, locations)
    (parser_has_diagnostics(value.diagnostics) == yes) { out value }
    out parser_ok("out", parser_loc(parser_group2("out", value.node.datum), token, locations), value.next)
}

skill parser_drum(tokens, start, path, locations) {
    @token = parser_at(tokens, start)
    @open = parser_expect(tokens, start + 1, "LPAREN", "expected ( after drum", path)
    (parser_has_diagnostics(open.diagnostics) == yes) { out open }
    @count = parser_expression(tokens, open.next, path, locations)
    (parser_has_diagnostics(count.diagnostics) == yes) { out count }
    @close = parser_expect(tokens, count.next, "RPAREN", "expected RPAREN", path)
    (parser_has_diagnostics(close.diagnostics) == yes) { out close }
    @body = parser_block(tokens, close.next, path, locations)
    (parser_has_diagnostics(body.diagnostics) == yes) { out body }
    out parser_ok("drum", parser_loc(parser_group3("drum", count.node.datum, body.node.datum), token, locations), body.next)
}

skill parser_paren_statement(tokens, start, path, locations) {
    @token = parser_at(tokens, start)
    @value = parser_expression(tokens, start + 1, path, locations)
    (parser_has_diagnostics(value.diagnostics) == yes) { out value }
    @close = parser_expect(tokens, value.next, "RPAREN", "expected RPAREN", path)
    (parser_has_diagnostics(close.diagnostics) == yes) { out close }
    @open = parser_expect(tokens, close.next, "LBRACE", "expected LBRACE", path)
    (parser_has_diagnostics(open.diagnostics) == yes) { out open }
    @next = parser_skip_lines(tokens, open.next)
    (parser_is(tokens, next, "DOT") == yes) {
        @cases = parser_group2("switch", value.node.datum)
        @done = no
        @diagnostics = []
        @count = core.group.count(tokens)
        drum (count) {
            (done == no) {
                (parser_is(tokens, next, "RBRACE") == yes) { next = next + 1 done = yes }
                (done == no) {
                    @case_token = parser_at(tokens, next)
                    @dot = parser_expect(tokens, next, "DOT", "expected DOT", path)
                    (parser_has_diagnostics(dot.diagnostics) == yes) { diagnostics = dot.diagnostics done = yes }
                    (done == no) {
                        (parser_is(tokens, dot.next, "IDENT") == no) { @failure = parser_fail(tokens, dot.next, "expected switch case tag", path) diagnostics = failure.diagnostics done = yes }
                    }
                    (done == no) {
                        @tag_token = parser_at(tokens, dot.next)
                        @tag = tag_token.value
                        @arrow = parser_expect(tokens, dot.next + 1, "ARROW", "expected ARROW", path)
                        (parser_has_diagnostics(arrow.diagnostics) == yes) { diagnostics = arrow.diagnostics done = yes }
                        (done == no) {
                            @body = parser_expression(tokens, arrow.next, path, locations)
                            (parser_has_diagnostics(body.diagnostics) == yes) { diagnostics = body.diagnostics done = yes }
                            (done == no) {
                                cases = core.group.add(cases, parser_loc(parser_group3("case", tag, body.node.datum), case_token, locations))
                                next = body.next
                                (parser_is(tokens, next, "COMMA") == yes) { next = next + 1 }
                                next = parser_skip_lines(tokens, next)
                            }
                        }
                    }
                }
            }
        }
        out SalticRead { node = parser_node("switch", parser_loc(cases, token, locations)) next = next diagnostics = diagnostics }
    }
    @items = parser_group1("block")
    @if_done = no
    @if_diagnostics = []
    @if_count = core.group.count(tokens)
    drum (if_count) {
        (if_done == no) {
            (parser_is(tokens, next, "RBRACE") == yes) { next = next + 1 if_done = yes }
            (if_done == no) {
              (parser_is(tokens, next, "EOF") == yes) { @failure = parser_fail(tokens, next, "expected }", path) if_diagnostics = failure.diagnostics if_done = yes }
            }
            (if_done == no) {
                @statement = parser_statement(tokens, next, path, locations)
                (parser_has_diagnostics(statement.diagnostics) == yes) { if_diagnostics = statement.diagnostics if_done = yes }
                (if_done == no) { items = core.group.add(items, statement.node.datum) next = parser_skip_lines(tokens, statement.next) }
            }
        }
    }
    @located_body = parser_loc(items, token, locations)
    out SalticRead { node = parser_node("if", parser_loc(parser_group3("if", value.node.datum, located_body), token, locations)) next = next diagnostics = if_diagnostics }
}

skill parser_statement(tokens, start, path, locations) {
    @token = parser_at(tokens, start)
    (token.kind == "AT") { out parser_var(tokens, start, path, locations) }
    (token.kind == "OUT") { out parser_out(tokens, start, path, locations) }
    (token.kind == "DRUM") { out parser_drum(tokens, start, path, locations) }
    (token.kind == "LPAREN") { out parser_paren_statement(tokens, start, path, locations) }
    (token.kind == "IDENT") {
        (parser_is(tokens, start + 1, "ASSIGN") == yes) { out parser_assign(tokens, start, path, locations) }
    }
    @expression = parser_expression(tokens, start, path, locations)
    (parser_has_diagnostics(expression.diagnostics) == yes) { out expression }
    out parser_ok("expr", parser_group2("expr", expression.node.datum), expression.next)
}

skill parser_use(tokens, start, path, locations) {
    @token = parser_at(tokens, start)
    @module = parser_path(tokens, start + 1, path, no)
    (parser_has_diagnostics(module.diagnostics) == yes) { out module }
    @parts = module.node.datum
    @datum = parser_group1("use")
    datum = parser_append_tail(datum, parts, 1)
    out parser_ok("use", parser_loc(datum, token, locations), module.next)
}

skill parser_entry(tokens, start, path, locations) {
    @token = parser_at(tokens, start)
    @open = parser_expect(tokens, start + 1, "LPAREN", "expected ( after program", path)
    (parser_has_diagnostics(open.diagnostics) == yes) { out open }
    @params = parser_params(tokens, open.next, path)
    (parser_has_diagnostics(params.diagnostics) == yes) { out params }
    @close = parser_expect(tokens, params.next, "RPAREN", "expected RPAREN", path)
    (parser_has_diagnostics(close.diagnostics) == yes) { out close }
    @body = parser_block(tokens, close.next, path, locations)
    (parser_has_diagnostics(body.diagnostics) == yes) { out body }
    out parser_ok("entry", parser_loc(parser_group3("entry", params.node.datum, body.node.datum), token, locations), body.next)
}

skill parser_skill(tokens, start, path, locations) {
    @token = parser_at(tokens, start)
    (parser_is(tokens, start + 1, "IDENT") == no) { out parser_fail(tokens, start + 1, "expected skill name", path) }
    @name_token = parser_at(tokens, start + 1)
    @name = name_token.value
    @open = parser_expect(tokens, start + 2, "LPAREN", "expected LPAREN", path)
    (parser_has_diagnostics(open.diagnostics) == yes) { out open }
    @params = parser_params(tokens, open.next, path)
    (parser_has_diagnostics(params.diagnostics) == yes) { out params }
    @close = parser_expect(tokens, params.next, "RPAREN", "expected RPAREN", path)
    (parser_has_diagnostics(close.diagnostics) == yes) { out close }
    @body = parser_block(tokens, close.next, path, locations)
    (parser_has_diagnostics(body.diagnostics) == yes) { out body }
    out parser_ok("skill", parser_loc(parser_group4("skill", name, params.node.datum, body.node.datum), token, locations), body.next)
}

skill parser_constant(tokens, start, path, locations) {
    @token = parser_at(tokens, start)
    @value = parser_expression(tokens, start + 2, path, locations)
    (parser_has_diagnostics(value.diagnostics) == yes) { out value }
    out parser_ok("const", parser_loc(parser_group3("const", token.value, value.node.datum), token, locations), value.next)
}

skill parser_box(tokens, start, path, locations) {
    @token = parser_at(tokens, start)
    @fields = parser_fields(tokens, start + 3, path, locations)
    (parser_has_diagnostics(fields.diagnostics) == yes) { out fields }
    @datum = parser_group2("box", token.value)
    datum = parser_append_tail(datum, fields.node.datum, 0)
    out parser_ok("box", parser_loc(datum, token, locations), fields.next)
}

skill parser_enum(tokens, start, path, locations) {
    @token = parser_at(tokens, start)
    @open = parser_expect(tokens, start + 3, "LBRACE", "expected LBRACE", path)
    (parser_has_diagnostics(open.diagnostics) == yes) { out open }
    @datum = parser_group2("enum", token.value)
    @next = parser_skip_lines(tokens, open.next)
    @done = no
    @diagnostics = []
    @count = core.group.count(tokens)
    drum (count) {
        (done == no) {
            (parser_is(tokens, next, "RBRACE") == yes) { next = next + 1 done = yes }
            (done == no) {
                (parser_is(tokens, next, "IDENT") == no) { @failure = parser_fail(tokens, next, "expected enum variant", path) diagnostics = failure.diagnostics done = yes }
                (done == no) {
                    @variant_token = parser_at(tokens, next)
                    datum = core.group.add(datum, variant_token.value)
                    next = next + 1
                    (parser_is(tokens, next, "COMMA") == yes) { next = next + 1 }
                    next = parser_skip_lines(tokens, next)
                }
            }
        }
    }
    out SalticRead { node = parser_node("enum", parser_loc(datum, token, locations)) next = next diagnostics = diagnostics }
}

skill parser_top(tokens, start, path, locations) {
    @token = parser_at(tokens, start)
    (token.kind == "USE") { out parser_use(tokens, start, path, locations) }
    (token.kind == "PROGRAM") { out parser_entry(tokens, start, path, locations) }
    (token.kind == "SKILL") { out parser_skill(tokens, start, path, locations) }
    (token.kind == "IDENT") {
        (parser_is(tokens, start + 1, "ASSIGN") == yes) {
            (parser_is(tokens, start + 2, "BOX") == yes) { out parser_box(tokens, start, path, locations) }
            (parser_is(tokens, start + 2, "ENUM") == yes) { out parser_enum(tokens, start, path, locations) }
            out parser_constant(tokens, start, path, locations)
        }
    }
    out parser_fail(tokens, start, "expected top-level declaration", path)
}

skill parser_parse_tokens_mode(tokens, path, locations) {
    @ast = parser_group1("program")
    @next = parser_skip_lines(tokens, 0)
    @diagnostics = []
    @done = no
    @count = core.group.count(tokens)
    drum (count) {
        (done == no) {
            (parser_is(tokens, next, "EOF") == yes) { done = yes }
            (done == no) {
                @item = parser_top(tokens, next, path, locations)
                (parser_has_diagnostics(item.diagnostics) == yes) { diagnostics = item.diagnostics done = yes }
                (done == no) { ast = core.group.add(ast, item.node.datum) next = parser_skip_lines(tokens, item.next) }
            }
        }
    }
    out SalticParse { ast = ast tokens = tokens diagnostics = diagnostics }
}

skill parser_parse_tokens(tokens, path) {
    out parser_parse_tokens_mode(tokens, path, no)
}

skill parser_parse_tokens_loc(tokens, path) {
    out parser_parse_tokens_mode(tokens, path, yes)
}

skill parser_parse_string(source, path) {
    @scan = parser_lex(source, path)
    (parser_has_diagnostics(scan.diagnostics) == yes) { out SalticParse { ast = [] tokens = scan.tokens diagnostics = scan.diagnostics } }
    out parser_parse_tokens(scan.tokens, path)
}

skill parser_parse_string_loc(source, path) {
    @scan = parser_lex(source, path)
    (parser_has_diagnostics(scan.diagnostics) == yes) { out SalticParse { ast = [] tokens = scan.tokens diagnostics = scan.diagnostics } }
    out parser_parse_tokens_loc(scan.tokens, path)
}

skill parser_ast_datum(source, path) {
    @parsed = parser_parse_string(source, path)
    out parsed.ast
}

skill parser_ast_datum_loc(source, path) {
    @parsed = parser_parse_string_loc(source, path)
    out parsed.ast
}

skill parser_group_contains(group, value) {
    @found = no
    @index = 0
    @count = core.group.count(group)
    drum (count) {
        (index < count) {
            (core.group.item(group, index) == value) { found = yes }
            index = index + 1
        }
    }
    out found
}

skill parser_strip_loc(datum) {
    (core.group.count(datum) == 4) {
        (core.group.item(datum, 0) == "loc") { out core.group.item(datum, 3) }
    }
    out datum
}

skill parser_dirname(path) {
    @last = 0
    @index = 0
    @length = core.str.len(path)
    drum (length) {
        (index < length) {
            (core.str.at(path, index) == "/") { last = index }
            index = index + 1
        }
    }
    (last == 0) {
        (core.str.starts_with(path, "/") == yes) { out "/" }
        out "."
    }
    out core.str.slice(path, 0, last)
}

skill parser_join_path(base, relative) {
    (core.str.ends_with(base, "/") == yes) { out core.str.add(base, relative) }
    out core.str.add(core.str.add(base, "/"), relative)
}

skill parser_module_relative(parts) {
    @relative = ""
    @index = 0
    @count = core.group.count(parts)
    drum (count) {
        (index < count) {
            (index > 0) { relative = core.str.add(relative, "/") }
            relative = core.str.add(relative, core.group.item(parts, index))
            index = index + 1
        }
    }
    out core.str.add(relative, ".s")
}

skill parser_module_text(parts) {
    @text = ""
    @index = 0
    @count = core.group.count(parts)
    drum (count) {
        (index < count) {
            (index > 0) { text = core.str.add(text, ".") }
            text = core.str.add(text, core.group.item(parts, index))
            index = index + 1
        }
    }
    out text
}

skill parser_resolve_module(source_path, parts, root) {
    @base = parser_dirname(source_path)
    @first = core.group.item(parts, 0)
    (first == "s") { base = root }
    (first == "s2") { base = root }
    out parser_join_path(base, parser_module_relative(parts))
}

skill parser_load_error(path, message, included) {
    out SalticLoad { ast = parser_group1("program") included = included diagnostics = parser_group1(core.str.add(core.str.add("modules: ", message), path)) }
}

skill parser_expand_file(path, root, locations, included, stack) {
    (parser_group_contains(stack, path) == yes) { out parser_load_error(path, "cyclic import involving ", included) }
    (parser_group_contains(included, path) == yes) { out SalticLoad { ast = parser_group1("program") included = included diagnostics = [] } }
    @next_included = core.group.add(included, path)
    @source = core_file_read_text(path) rescue |error| {
        out parser_load_error(path, "module not found at ", next_included)
    }
    @parsed = parser_parse_string(source, path)
    (locations == yes) { parsed = parser_parse_string_loc(source, path) }
    (parser_has_diagnostics(parsed.diagnostics) == yes) { out SalticLoad { ast = parser_group1("program") included = next_included diagnostics = parsed.diagnostics } }
    @output = parser_group1("program")
    @next_stack = core.group.add(stack, path)
    @index = 1
    @count = core.group.count(parsed.ast)
    @diagnostics = []
    @active = yes
    drum (count) {
        (active == yes) {
            (index < count) {
                @item = core.group.item(parsed.ast, index)
                output = core.group.add(output, item)
                @plain = parser_strip_loc(item)
                (core.group.item(plain, 0) == "use") {
                    @parts = []
                    @part_index = 1
                    @part_count = core.group.count(plain)
                    drum (part_count) {
                        (part_index < part_count) { parts = core.group.add(parts, core.group.item(plain, part_index)) part_index = part_index + 1 }
                    }
                    @is_core = no
                    (core.group.count(parts) == 1) {
                        (core.group.item(parts, 0) == "core") { is_core = yes }
                    }
                    (is_core == yes) {
                        @core_files = ["file.s", "json.s", "str.s", "num.s", "group.s"]
                        @core_index = 0
                        @core_count = core.group.count(core_files)
                        drum (core_count) {
                            (active == yes) {
                                (core_index < core_count) {
                                    @core_path = parser_join_path(parser_join_path(root, "core"), core.group.item(core_files, core_index))
                                    @loaded = parser_expand_file(core_path, root, locations, next_included, next_stack)
                                    next_included = loaded.included
                                    (parser_has_diagnostics(loaded.diagnostics) == yes) { diagnostics = loaded.diagnostics active = no }
                                    (active == yes) { output = parser_append_tail(output, loaded.ast, 1) }
                                    core_index = core_index + 1
                                }
                            }
                        }
                    }
                    (is_core == no) {
                        @module_path = parser_resolve_module(path, parts, root)
                        @loaded = parser_expand_file(module_path, root, locations, next_included, next_stack)
                        next_included = loaded.included
                        (parser_has_diagnostics(loaded.diagnostics) == yes) { diagnostics = loaded.diagnostics active = no }
                        (active == yes) { output = parser_append_tail(output, loaded.ast, 1) }
                    }
                }
                index = index + 1
            }
            (index == count) { active = no }
        }
    }
    out SalticLoad { ast = output included = next_included diagnostics = diagnostics }
}

skill parser_load_file(path, root) {
    out parser_expand_file(path, root, no, [], [])
}

skill parser_load_file_loc(path, root) {
    out parser_expand_file(path, root, yes, [], [])
}
