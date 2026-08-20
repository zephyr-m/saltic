use core

TokenKind = enum {
    INVALID, IDENT, NUMBER, STRING, NEWLINE, EOF,
    SKILL, PROGRAM, USE, BOX, OUT, ENUM, DRUM, RESCUE,
    YES, NO, NONE,
    AT, LBRACE, RBRACE, LBRACKET, RBRACKET, LPAREN, RPAREN,
    COMMA, DOT, PIPE, ASSIGN, EQ, ARROW,
    GT, LT, PLUS, MINUS, STAR, SLASH,
}

Newline = "\n"
Tab = "\t"
Quote = "\""
Escape = "\\"
EscapeNewline = "n"
EscapeTab = "t"

Signs = ["@", "{", "}", "[", "]", "(", ")", ",", ".", "|", "=", ">", "<", "+", "-", "*", "/"]

SignKinds = [
    TokenKind.AT, TokenKind.LBRACE, TokenKind.RBRACE,
    TokenKind.LBRACKET, TokenKind.RBRACKET, TokenKind.LPAREN, TokenKind.RPAREN,
    TokenKind.COMMA, TokenKind.DOT, TokenKind.PIPE, TokenKind.ASSIGN,
    TokenKind.GT, TokenKind.LT, TokenKind.PLUS, TokenKind.MINUS, TokenKind.STAR, TokenKind.SLASH,
]

Keywords = ["skill", "program", "use", "Box", "out", "enum", "drum", "rescue", "yes", "no", "none"]

KeywordKinds = [
    TokenKind.SKILL, TokenKind.PROGRAM, TokenKind.USE, TokenKind.BOX,
    TokenKind.OUT, TokenKind.ENUM, TokenKind.DRUM, TokenKind.RESCUE,
    TokenKind.YES, TokenKind.NO, TokenKind.NONE,
]

SalticToken = Box {
    kind = TokenKind.INVALID
    value = ""
    line = 1
    col = 1
}

SalticScan = Box {
    tokens = []
    diagnostics = []
}

SalticLexeme = Box {
    token = none
    next = 0
    line = 1
    col = 1
    diagnostics = []
}

SalticLexer = Box {
    source = ""
    path = ""

    skill token(kind, value, line, col) {
        out SalticToken { kind = kind value = value line = line col = col }
    }

    skill ascii_letter(ch) {
        out core.str.contains("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", ch)
    }

    skill ident_start(ch) {
        (ascii_letter(ch) == yes) { out yes }
        (ch == "_") { out yes }
        @upper = core.str.upper(ch)
        @lower = core.str.lower(ch)
        (upper == lower) { out no }
        out yes
    }

    skill ident_part(ch) {
        (ident_start(ch) == yes) { out yes }
        out parser_is_digit(ch)
    }

    skill word(start, line, col) {
        @index = start
        @next_col = col
        @length = core.str.len(source)
        @reading = yes
        drum (length) {
            (reading == yes) {
                (index < length) {
                    @part = core.str.at(source, index)
                    (ident_part(part) == yes) { index = index + 1 next_col = next_col + 1 }
                    (ident_part(part) == no) { reading = no }
                }
                (index == length) { reading = no }
            }
        }
        @value = core.str.slice(source, start, index)
        out SalticLexeme {
            token = token(word_kind(value), value, line, col)
            next = index
            line = line
            col = next_col
        }
    }

    skill number(start, line, col) {
        @index = start
        @next_col = col
        @length = core.str.len(source)
        @dot = no
        @reading = yes
        drum (length) {
            (reading == yes) {
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
                    (take == yes) { index = index + 1 next_col = next_col + 1 }
                    (take == no) { reading = no }
                }
                (index == length) { reading = no }
            }
        }
        out SalticLexeme {
            token = token(TokenKind.NUMBER, core.str.slice(source, start, index), line, col)
            next = index
            line = line
            col = next_col
        }
    }

    skill text(start, line, col) {
        @index = start + 1
        @next_line = line
        @next_col = col + 1
        @length = core.str.len(source)
        @value = ""
        @closed = no
        @diagnostics = []
        drum (length) {
            (closed == no) {
                (index < length) {
                    @ch = core.str.at(source, index)
                    (ch == Quote) { closed = yes index = index + 1 next_col = next_col + 1 }
                    (ch == Escape) {
                        (closed == no) {
                            (index + 1 < length) {
                                @escape = core.str.at(source, index + 1)
                                @decoded = escape
                                (escape == EscapeNewline) { decoded = Newline }
                                (escape == EscapeTab) { decoded = Tab }
                                (escape == Quote) { decoded = Quote }
                                (escape == Escape) { decoded = Escape }
                                value = core.str.add(value, decoded)
                                index = index + 2
                                next_col = next_col + 2
                            }
                            (index + 1 == length) {
                                diagnostics = core.group.add(diagnostics, parser_diagnostic(path, next_line, next_col, "unterminated escape"))
                                closed = yes
                            }
                        }
                    }
                    (closed == no) {
                        (ch == Newline) { value = core.str.add(value, ch) index = index + 1 next_line = next_line + 1 next_col = 1 }
                        @ordinary = yes
                        (ch == Newline) { ordinary = no }
                        (ch == Quote) { ordinary = no }
                        (ch == Escape) { ordinary = no }
                        (ordinary == yes) { value = core.str.add(value, ch) index = index + 1 next_col = next_col + 1 }
                    }
                }
                (closed == no) {
                    (index == length) {
                        diagnostics = core.group.add(diagnostics, parser_diagnostic(path, line, col, "unterminated string"))
                        closed = yes
                    }
                }
            }
        }
        @result_token = none
        (parser_has_diagnostics(diagnostics) == no) { result_token = token(TokenKind.STRING, value, line, col) }
        out SalticLexeme {
            token = result_token
            next = index
            line = next_line
            col = next_col
            diagnostics = diagnostics
        }
    }

    skill table_kind(values, kinds, value, fallback) {
        @index = 0
        @count = core.group.count(values)
        drum (count) {
            (index < count) {
                (core.group.item(values, index) == value) { out core.group.item(kinds, index) }
                index = index + 1
            }
        }
        out fallback
    }

    skill word_kind(word) {
        out table_kind(Keywords, KeywordKinds, word, TokenKind.IDENT)
    }

    skill sign_kind(ch) {
        out table_kind(Signs, SignKinds, ch, TokenKind.INVALID)
    }

    skill scan() {
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
                    (ch == Tab) { index = index + 1 col = col + 1 handled = yes }
                    (ch == Newline) {
                        tokens = core.group.add(tokens, token(TokenKind.NEWLINE, Newline, line, col))
                        index = index + 1
                        line = line + 1
                        col = 1
                        handled = yes
                    }
                    (handled == no) {
                        (ident_start(ch) == yes) {
                            @lexeme = word(index, line, col)
                            tokens = core.group.add(tokens, lexeme.token)
                            index = lexeme.next
                            line = lexeme.line
                            col = lexeme.col
                            handled = yes
                        }
                    }
                    (handled == no) {
                        (parser_is_digit(ch) == yes) {
                            @lexeme = number(index, line, col)
                            tokens = core.group.add(tokens, lexeme.token)
                            index = lexeme.next
                            line = lexeme.line
                            col = lexeme.col
                            handled = yes
                        }
                    }
                    (handled == no) {
                        (ch == Quote) {
                            @lexeme = text(index, line, col)
                            index = lexeme.next
                            line = lexeme.line
                            col = lexeme.col
                            diagnostics = lexeme.diagnostics
                            (parser_has_diagnostics(diagnostics) == no) { tokens = core.group.add(tokens, lexeme.token) }
                            (parser_has_diagnostics(diagnostics) == yes) { active = no }
                            handled = yes
                        }
                    }
                    (handled == no) {
                        @pair = ""
                        (index + 1 < length) { pair = core.str.slice(source, index, index + 2) }
                        (pair == "==") { tokens = core.group.add(tokens, token(TokenKind.EQ, pair, line, col)) index = index + 2 col = col + 2 handled = yes }
                        (pair == "=>") { tokens = core.group.add(tokens, token(TokenKind.ARROW, pair, line, col)) index = index + 2 col = col + 2 handled = yes }
                    }
                    (handled == no) {
                        @sign = sign_kind(ch)
                        @valid_sign = yes
                        (sign == TokenKind.INVALID) {
                            @message = core.str.add("unexpected character ", ch)
                            diagnostics = core.group.add(diagnostics, parser_diagnostic(path, line, col, message))
                            active = no
                            valid_sign = no
                        }
                        (valid_sign == yes) {
                            tokens = core.group.add(tokens, token(sign, ch, line, col))
                            index = index + 1
                            col = col + 1
                            handled = yes
                        }
                    }
                }
                (index == length) { active = no }
            }
        }
        tokens = core.group.add(tokens, token(TokenKind.EOF, "", line, col))
        out SalticScan { tokens = tokens diagnostics = diagnostics }
    }
}

SalticCursor = Box {
    tokens = []
    path = ""

    skill count() {
        out core.group.count(tokens)
    }

    skill at(index) {
        out core.group.item(tokens, index)
    }

    skill is(index, kind) {
        @token = at(index)
        out token.kind == kind
    }

    skill skip_lines(index) {
        @next = index
        @length = count()
        drum (length) {
            (next < length) {
                (is(next, TokenKind.NEWLINE) == yes) { next = next + 1 }
            }
        }
        out next
    }

    skill fail(index, message) {
        @token = at(index)
        @tail = core.str.add(message, ", got ")
        tail = core.str.add(tail, token.kind)
        out SalticRead {
            node = parser_node("", [])
            next = index
            diagnostics = parser_group1(parser_diagnostic(path, token.line, token.col, tail))
        }
    }

    skill expect(index, kind, message) {
        @token = at(index)
        (is(index, kind) == yes) { out parser_ok("token", parser_group1(token.value), index + 1) }
        out fail(index, message)
    }
}

SalticParser = Box {
    cursor = SalticCursor {}
    locations = no

    skill field_item(start, item_message) {
        (cursor.is(start, TokenKind.IDENT) == no) { out cursor.fail(start, item_message) }
        @name_token = cursor.at(start)
        @eq = cursor.expect(start + 1, TokenKind.ASSIGN, "expected = after field name")
        (parser_has_diagnostics(eq.diagnostics) == yes) { out eq }
        @value = expression(eq.next)
        (parser_has_diagnostics(value.diagnostics) == yes) { out value }
        out parser_ok("field", parser_group3("field", name_token.value, value.node.datum), value.next)
    }

    skill sequence_item(start, item_kind, item_message) {
        (item_kind == "name") {
            (cursor.is(start, TokenKind.IDENT) == no) { out cursor.fail(start, item_message) }
            @token = cursor.at(start)
            out parser_ok("name", token.value, start + 1)
        }
        (item_kind == "expression") {
            @value = expression(start)
            (parser_has_diagnostics(value.diagnostics) == yes) { out value }
            out parser_ok("expression", value.node.datum, value.next)
        }
        (item_kind == "field") { out field_item(start, item_message) }
        (item_kind == "member") {
            (cursor.is(start, TokenKind.SKILL) == yes) {
                @member_skill = subject_skill(start)
                (parser_has_diagnostics(member_skill.diagnostics) == yes) { out member_skill }
                out parser_ok("member", member_skill.node.datum, member_skill.next)
            }
            out field_item(start, item_message)
        }
        (item_kind == "statement") {
            @value = statement(start)
            (parser_has_diagnostics(value.diagnostics) == yes) { out value }
            out parser_ok("statement", value.node.datum, value.next)
        }
        out cursor.fail(start, item_message)
    }

    skill sequence(start, end_kind, item_kind, item_message, eof_message, require_separator, allow_comma) {
        @items = []
        @next = cursor.skip_lines(start)
        @done = no
        @diagnostics = []
        @count = cursor.count()
        drum (count) {
            (done == no) {
                (cursor.is(next, end_kind) == yes) {
                    next = next + 1
                    done = yes
                }
                (done == no) {
                    (cursor.is(next, TokenKind.EOF) == yes) {
                        @failure = cursor.fail(next, eof_message)
                        diagnostics = failure.diagnostics
                        done = yes
                    }
                }
                (done == no) {
                    @item = sequence_item(next, item_kind, item_message)
                    (parser_has_diagnostics(item.diagnostics) == yes) { diagnostics = item.diagnostics done = yes }
                    (done == no) {
                        items = core.group.add(items, item.node.datum)
                        next = item.next
                        @separated = no
                        (allow_comma == yes) {
                            (cursor.is(next, TokenKind.COMMA) == yes) {
                                next = next + 1
                                separated = yes
                            }
                        }
                        @before_lines = next
                        next = cursor.skip_lines(next)
                        (next > before_lines) { separated = yes }
                        (cursor.is(next, end_kind) == no) {
                            (require_separator == yes) {
                                (separated == no) {
                                    @separator_failure = cursor.fail(next, "expected separator")
                                    diagnostics = separator_failure.diagnostics
                                    done = yes
                                }
                            }
                        }
                    }
                }
            }
        }
        out SalticRead { node = parser_node("sequence", items) next = next diagnostics = diagnostics }
    }

    skill names(start, end_kind, item_message) {
        @items = sequence(start, end_kind, "name", item_message, item_message, yes, yes)
        out SalticRead { node = parser_node("names", items.node.datum) next = items.next diagnostics = items.diagnostics }
    }

    skill params(start) {
        @parsed_names = names(start, TokenKind.RPAREN, "expected parameter name")
        out SalticRead { node = parser_node("params", parsed_names.node.datum) next = parsed_names.next diagnostics = parsed_names.diagnostics }
    }

    skill module(start) {
        @token = cursor.at(start)
        @module = path_at(start + 1, no)
        (parser_has_diagnostics(module.diagnostics) == yes) { out module }
        @parts = module.node.datum
        @datum = parser_group1("use")
        datum = parser_append_tail(datum, parts, 1)
        out parser_ok("use", parser_loc(datum, token, locations), module.next)
    }

    skill constant(start) {
        @token = cursor.at(start)
        @value = expression(start + 2)
        (parser_has_diagnostics(value.diagnostics) == yes) { out value }
        out parser_ok("const", parser_loc(parser_group3("const", token.value, value.node.datum), token, locations), value.next)
    }

    skill entry(start) {
        @token = cursor.at(start)
        @open = cursor.expect(start + 1, TokenKind.LPAREN, "expected ( after program")
        (parser_has_diagnostics(open.diagnostics) == yes) { out open }
        @params = params(open.next)
        (parser_has_diagnostics(params.diagnostics) == yes) { out params }
        @body = block(params.next)
        (parser_has_diagnostics(body.diagnostics) == yes) { out body }
        out parser_ok("entry", parser_loc(parser_group3("entry", params.node.datum, body.node.datum), token, locations), body.next)
    }

    skill named_skill(start) {
        @token = cursor.at(start)
        (cursor.is(start + 1, TokenKind.IDENT) == no) { out cursor.fail(start + 1, "expected skill name") }
        @name_token = cursor.at(start + 1)
        @name = name_token.value
        @open = cursor.expect(start + 2, TokenKind.LPAREN, "expected LPAREN")
        (parser_has_diagnostics(open.diagnostics) == yes) { out open }
        @params = params(open.next)
        (parser_has_diagnostics(params.diagnostics) == yes) { out params }
        @body = block(params.next)
        (parser_has_diagnostics(body.diagnostics) == yes) { out body }
        out parser_ok("skill", parser_loc(parser_group4("skill", name, params.node.datum, body.node.datum), token, locations), body.next)
    }

    skill subject_skill(start) {
        @token = cursor.at(start)
        (cursor.is(start + 1, TokenKind.IDENT) == no) { out cursor.fail(start + 1, "expected skill name") }
        @name_token = cursor.at(start + 1)
        @open = cursor.expect(start + 2, TokenKind.LPAREN, "expected LPAREN")
        (parser_has_diagnostics(open.diagnostics) == yes) { out open }
        @params = params(open.next)
        (parser_has_diagnostics(params.diagnostics) == yes) { out params }
        @body = block(params.next)
        (parser_has_diagnostics(body.diagnostics) == yes) { out body }
        out parser_ok("subject-skill", parser_loc(parser_group4("subject-skill", name_token.value, params.node.datum, body.node.datum), token, locations), body.next)
    }

    skill box_members(start) {
        @open = cursor.expect(start, TokenKind.LBRACE, "expected LBRACE")
        (parser_has_diagnostics(open.diagnostics) == yes) { out open }
        @members = sequence(open.next, TokenKind.RBRACE, "member", "expected field or skill", "expected }", no, yes)
        out SalticRead { node = parser_node("box-members", members.node.datum) next = members.next diagnostics = members.diagnostics }
    }

    skill enumeration(start) {
        @token = cursor.at(start)
        @open = cursor.expect(start + 3, TokenKind.LBRACE, "expected LBRACE")
        (parser_has_diagnostics(open.diagnostics) == yes) { out open }
        @datum = parser_group2("enum", token.value)
        @variants = names(open.next, TokenKind.RBRACE, "expected enum variant")
        (parser_has_diagnostics(variants.diagnostics) == yes) { out variants }
        datum = parser_append_tail(datum, variants.node.datum, 0)
        out parser_ok("enum", parser_loc(datum, token, locations), variants.next)
    }

    skill box(start) {
        @token = cursor.at(start)
        @members = box_members(start + 3)
        (parser_has_diagnostics(members.diagnostics) == yes) { out members }
        @datum = parser_group2("box", token.value)
        datum = parser_append_tail(datum, members.node.datum, 0)
        out parser_ok("box", parser_loc(datum, token, locations), members.next)
    }

    skill top(start) {
        @token = cursor.at(start)
        (token.kind == TokenKind.USE) { out module(start) }
        (token.kind == TokenKind.PROGRAM) { out entry(start) }
        (token.kind == TokenKind.SKILL) { out named_skill(start) }
        (token.kind == TokenKind.IDENT) {
            (cursor.is(start + 1, TokenKind.ASSIGN) == yes) {
                (cursor.is(start + 2, TokenKind.BOX) == yes) { out box(start) }
                (cursor.is(start + 2, TokenKind.ENUM) == yes) { out enumeration(start) }
                out constant(start)
            }
        }
        out cursor.fail(start, "expected top-level declaration")
    }

    skill parse_tokens() {
        @ast = parser_group1("program")
        @next = cursor.skip_lines(0)
        @diagnostics = []
        @done = no
        @count = cursor.count()
        drum (count) {
            (done == no) {
                (cursor.is(next, TokenKind.EOF) == yes) { done = yes }
                (done == no) {
                    @item = top(next)
                    (parser_has_diagnostics(item.diagnostics) == yes) { diagnostics = item.diagnostics done = yes }
                    (done == no) { ast = core.group.add(ast, item.node.datum) next = cursor.skip_lines(item.next) }
                }
            }
        }
        out SalticParse { ast = ast tokens = cursor.tokens diagnostics = diagnostics }
    }

    skill path_at(start, with_locations) {
        @next = start
        (cursor.is(next, TokenKind.IDENT) == no) { out cursor.fail(next, "expected identifier") }
        @token = cursor.at(next)
        @parts = parser_group2("path", token.value)
        next = next + 1
        @count = cursor.count()
        @active = yes
        drum (count) {
            (active == yes) {
                (next + 1 < count) {
                    (cursor.is(next, TokenKind.DOT) == yes) {
                        @has_part = cursor.is(next + 1, TokenKind.IDENT)
                        (has_part == yes) {
                            @part_token = cursor.at(next + 1)
                            parts = core.group.add(parts, part_token.value)
                            next = next + 2
                        }
                        (has_part == no) { active = no }
                    }
                    (cursor.is(next, TokenKind.DOT) == no) { active = no }
                }
                (next + 1 == count) { active = no }
            }
        }
        out parser_ok("path", parser_loc(parts, token, with_locations), next)
    }

    skill expressions(start, end_kind) {
        @items = sequence(start, end_kind, "expression", "expected expression", "expected closing token", no, yes)
        out SalticRead { node = parser_node("expressions", items.node.datum) next = items.next diagnostics = items.diagnostics }
    }

    skill primary(start) {
        @token = cursor.at(start)
        (token.kind == TokenKind.NUMBER) { out parser_ok("number", parser_loc(parser_group2("number", parser_number_value(token.value)), token, locations), start + 1) }
        (token.kind == TokenKind.STRING) { out parser_ok("string", parser_loc(parser_group2("string", token.value), token, locations), start + 1) }
        (token.kind == TokenKind.YES) { out parser_ok("answer", parser_loc(parser_group2("answer", "yes"), token, locations), start + 1) }
        (token.kind == TokenKind.NO) { out parser_ok("answer", parser_loc(parser_group2("answer", "no"), token, locations), start + 1) }
        (token.kind == TokenKind.NONE) { out parser_ok("none", parser_loc(parser_group1("none"), token, locations), start + 1) }
        (token.kind == TokenKind.DOT) {
            (cursor.is(start + 1, TokenKind.IDENT) == no) { out cursor.fail(start + 1, "expected enum value") }
            @name_token = cursor.at(start + 1)
            out parser_ok("enum-value", parser_loc(parser_group2("enum-value", name_token.value), token, locations), start + 2)
        }
        (token.kind == TokenKind.LBRACKET) { out group(start) }
        (token.kind == TokenKind.IDENT) { out path_at(start, locations) }
        (token.kind == TokenKind.LPAREN) {
            @inside = expression(start + 1)
            (parser_has_diagnostics(inside.diagnostics) == yes) { out inside }
            @close = cursor.expect(inside.next, TokenKind.RPAREN, "expected RPAREN")
            (parser_has_diagnostics(close.diagnostics) == yes) { out close }
            out SalticRead { node = inside.node next = close.next diagnostics = [] }
        }
        out cursor.fail(start, "expected expression")
    }

    skill args(start) {
        @expressions = expressions(start + 1, TokenKind.RPAREN)
        out SalticRead { node = parser_node("args", expressions.node.datum) next = expressions.next diagnostics = expressions.diagnostics }
    }

    skill fields(start) {
        @open = cursor.expect(start, TokenKind.LBRACE, "expected LBRACE")
        (parser_has_diagnostics(open.diagnostics) == yes) { out open }
        @fields = sequence(open.next, TokenKind.RBRACE, "field", "expected field name", "expected }", no, yes)
        out SalticRead { node = parser_node("fields", fields.node.datum) next = fields.next diagnostics = fields.diagnostics }
    }

    skill postfix(start) {
        @base = primary(start)
        (parser_has_diagnostics(base.diagnostics) == yes) { out base }
        @node = base.node
        @next = base.next
        @active = yes
        @diagnostics = []
        @count = cursor.count()
        drum (count) {
            (active == yes) {
                (cursor.is(next, TokenKind.LPAREN) == yes) {
                    @call_token = cursor.at(next)
                    @args = args(next)
                    (parser_has_diagnostics(args.diagnostics) == yes) { diagnostics = args.diagnostics active = no }
                    (parser_has_diagnostics(args.diagnostics) == no) {
                        @call = parser_group2("call", node.datum)
                        call = parser_append_tail(call, args.node.datum, 0)
                        node = parser_node("call", parser_loc(call, call_token, locations))
                        next = args.next
                    }
                }
                (cursor.is(next, TokenKind.LPAREN) == no) {
                    @box_candidate = no
                    (node.tag == "path") {
                        @plain_path = node.datum
                        (locations == yes) { plain_path = core.group.item(node.datum, 3) }
                        (core.group.count(plain_path) == 2) {
                            (cursor.is(next, TokenKind.LBRACE) == yes) { box_candidate = yes }
                        }
                    }
                    (box_candidate == yes) {
                        @box_token = cursor.at(next)
                        @fields = fields(next)
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

    skill precedence(kind) {
        (kind == TokenKind.EQ) { out 1 }
        (kind == TokenKind.GT) { out 1 }
        (kind == TokenKind.LT) { out 1 }
        (kind == TokenKind.PLUS) { out 2 }
        (kind == TokenKind.MINUS) { out 2 }
        (kind == TokenKind.STAR) { out 3 }
        (kind == TokenKind.SLASH) { out 3 }
        out 0
    }

    skill binary(start, minimum) {
        @first = postfix(start)
        (parser_has_diagnostics(first.diagnostics) == yes) { out first }
        @left = first.node
        @next = first.next
        @active = yes
        @diagnostics = []
        @count = cursor.count()
        drum (count) {
            (active == yes) {
                @operator = cursor.at(next)
                @level = precedence(operator.kind)
                (level < minimum) { active = no }
                (level == 0) { active = no }
                (active == yes) {
                    @right = binary(next + 1, level + 1)
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

    skill expression(start) {
        @value = binary(start, 0)
        (parser_has_diagnostics(value.diagnostics) == yes) { out value }
        (cursor.is(value.next, TokenKind.RESCUE) == yes) {
            @rescue_token = cursor.at(value.next)
            @pipe = cursor.expect(value.next + 1, TokenKind.PIPE, "expected PIPE")
            (parser_has_diagnostics(pipe.diagnostics) == yes) { out pipe }
            (cursor.is(pipe.next, TokenKind.IDENT) == no) { out cursor.fail(pipe.next, "expected rescue error name") }
            @error_token = cursor.at(pipe.next)
            @error_name = error_token.value
            @pipe2 = cursor.expect(pipe.next + 1, TokenKind.PIPE, "expected PIPE")
            (parser_has_diagnostics(pipe2.diagnostics) == yes) { out pipe2 }
            @body = block(pipe2.next)
            (parser_has_diagnostics(body.diagnostics) == yes) { out body }
            out parser_ok("rescue", parser_loc(parser_group4("rescue", value.node.datum, error_name, body.node.datum), rescue_token, locations), body.next)
        }
        out value
    }

    skill group(start) {
        @token = cursor.at(start)
        @expressions = expressions(start + 1, TokenKind.RBRACKET)
        (parser_has_diagnostics(expressions.diagnostics) == yes) { out expressions }
        @items = parser_group1("group")
        items = parser_append_tail(items, expressions.node.datum, 0)
        out parser_ok("group", parser_loc(items, token, locations), expressions.next)
    }

    skill block(start) {
        @token = cursor.at(start)
        @open = cursor.expect(start, TokenKind.LBRACE, "expected LBRACE")
        (parser_has_diagnostics(open.diagnostics) == yes) { out open }
        @statements = sequence(open.next, TokenKind.RBRACE, "statement", "expected statement", "expected }", no, no)
        @items = parser_group1("block")
        items = parser_append_tail(items, statements.node.datum, 0)
        out SalticRead { node = parser_node("block", parser_loc(items, token, locations)) next = statements.next diagnostics = statements.diagnostics }
    }

    skill variable(start) {
        @token = cursor.at(start)
        (cursor.is(start + 1, TokenKind.IDENT) == no) { out cursor.fail(start + 1, "expected variable name") }
        @name_token = cursor.at(start + 1)
        @name = name_token.value
        @eq = cursor.expect(start + 2, TokenKind.ASSIGN, "expected = after variable name")
        (parser_has_diagnostics(eq.diagnostics) == yes) { out eq }
        @value = expression(eq.next)
        (parser_has_diagnostics(value.diagnostics) == yes) { out value }
        out parser_ok("var", parser_loc(parser_group3("var", name, value.node.datum), token, locations), value.next)
    }

    skill assign(start) {
        @token = cursor.at(start)
        @value = expression(start + 2)
        (parser_has_diagnostics(value.diagnostics) == yes) { out value }
        out parser_ok("assign", parser_loc(parser_group3("assign", token.value, value.node.datum), token, locations), value.next)
    }

    skill field_assign(start) {
        @token = cursor.at(start)
        @target = path_at(start, locations)
        (parser_has_diagnostics(target.diagnostics) == yes) { out target }
        @eq = cursor.expect(target.next, TokenKind.ASSIGN, "expected ASSIGN")
        (parser_has_diagnostics(eq.diagnostics) == yes) { out eq }
        @value = expression(eq.next)
        (parser_has_diagnostics(value.diagnostics) == yes) { out value }
        out parser_ok("field-assign", parser_loc(parser_group3("field-assign", target.node.datum, value.node.datum), token, locations), value.next)
    }

    skill out_statement(start) {
        @token = cursor.at(start)
        @value = expression(start + 1)
        (parser_has_diagnostics(value.diagnostics) == yes) { out value }
        out parser_ok("out", parser_loc(parser_group2("out", value.node.datum), token, locations), value.next)
    }

    skill drum_statement(start) {
        @token = cursor.at(start)
        @open = cursor.expect(start + 1, TokenKind.LPAREN, "expected ( after drum")
        (parser_has_diagnostics(open.diagnostics) == yes) { out open }
        @count = expression(open.next)
        (parser_has_diagnostics(count.diagnostics) == yes) { out count }
        @close = cursor.expect(count.next, TokenKind.RPAREN, "expected RPAREN")
        (parser_has_diagnostics(close.diagnostics) == yes) { out close }
        @body = block(close.next)
        (parser_has_diagnostics(body.diagnostics) == yes) { out body }
        out parser_ok("drum", parser_loc(parser_group3("drum", count.node.datum, body.node.datum), token, locations), body.next)
    }

    skill paren_statement(start) {
        @token = cursor.at(start)
        @value = expression(start + 1)
        (parser_has_diagnostics(value.diagnostics) == yes) { out value }
        @close = cursor.expect(value.next, TokenKind.RPAREN, "expected RPAREN")
        (parser_has_diagnostics(close.diagnostics) == yes) { out close }
        @open = cursor.expect(close.next, TokenKind.LBRACE, "expected LBRACE")
        (parser_has_diagnostics(open.diagnostics) == yes) { out open }
        @next = cursor.skip_lines(open.next)
        (cursor.is(next, TokenKind.DOT) == yes) {
            @cases = parser_group2("switch", value.node.datum)
            @done = no
            @diagnostics = []
            @count = cursor.count()
            drum (count) {
                (done == no) {
                    (cursor.is(next, TokenKind.RBRACE) == yes) { next = next + 1 done = yes }
                    (done == no) {
                        @case_token = cursor.at(next)
                        @dot = cursor.expect(next, TokenKind.DOT, "expected DOT")
                        (parser_has_diagnostics(dot.diagnostics) == yes) { diagnostics = dot.diagnostics done = yes }
                        (done == no) {
                            (cursor.is(dot.next, TokenKind.IDENT) == no) { @failure = cursor.fail(dot.next, "expected switch case tag") diagnostics = failure.diagnostics done = yes }
                        }
                        (done == no) {
                            @tag_token = cursor.at(dot.next)
                            @tag = tag_token.value
                            @arrow = cursor.expect(dot.next + 1, TokenKind.ARROW, "expected ARROW")
                            (parser_has_diagnostics(arrow.diagnostics) == yes) { diagnostics = arrow.diagnostics done = yes }
                            (done == no) {
                                @body = expression(arrow.next)
                                (parser_has_diagnostics(body.diagnostics) == yes) { diagnostics = body.diagnostics done = yes }
                                (done == no) {
                                    cases = core.group.add(cases, parser_loc(parser_group3("case", tag, body.node.datum), case_token, locations))
                                    next = body.next
                                    (cursor.is(next, TokenKind.COMMA) == yes) { next = next + 1 }
                                    next = cursor.skip_lines(next)
                                }
                            }
                        }
                    }
                }
            }
            out SalticRead { node = parser_node("switch", parser_loc(cases, token, locations)) next = next diagnostics = diagnostics }
        }
        @statements = sequence(next, TokenKind.RBRACE, "statement", "expected statement", "expected }", no, no)
        @items = parser_group1("block")
        items = parser_append_tail(items, statements.node.datum, 0)
        @located_body = parser_loc(items, token, locations)
        out SalticRead { node = parser_node("if", parser_loc(parser_group3("if", value.node.datum, located_body), token, locations)) next = statements.next diagnostics = statements.diagnostics }
    }

    skill statement(start) {
        @token = cursor.at(start)
        (token.kind == TokenKind.AT) { out variable(start) }
        (token.kind == TokenKind.OUT) { out out_statement(start) }
        (token.kind == TokenKind.DRUM) { out drum_statement(start) }
        (token.kind == TokenKind.LPAREN) { out paren_statement(start) }
        (token.kind == TokenKind.IDENT) {
            (cursor.is(start + 1, TokenKind.ASSIGN) == yes) { out assign(start) }
            @target = path_at(start, no)
            (cursor.is(target.next, TokenKind.ASSIGN) == yes) { out field_assign(start) }
        }
        @expression = expression(start)
        (parser_has_diagnostics(expression.diagnostics) == yes) { out expression }
        out parser_ok("expr", parser_group2("expr", expression.node.datum), expression.next)
    }

}

SalticLoader = Box {
    root = ""
    locations = no

    skill contains(group, value) {
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

    skill strip_loc(datum) {
        (core.group.count(datum) == 4) {
            (core.group.item(datum, 0) == "loc") { out core.group.item(datum, 3) }
        }
        out datum
    }

    skill dirname(path) {
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

    skill join_path(base, relative) {
        (core.str.ends_with(base, "/") == yes) { out core.str.add(base, relative) }
        out core.str.add(core.str.add(base, "/"), relative)
    }

    skill module_relative(parts) {
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

    skill resolve_module(source_path, parts) {
        @base = dirname(source_path)
        @first = core.group.item(parts, 0)
        (first == "s") { base = root }
        (first == "s2") { base = root }
        out join_path(base, module_relative(parts))
    }

    skill load_error(path, message, included) {
        out SalticLoad { ast = parser_group1("program") included = included diagnostics = parser_group1(core.str.add(core.str.add("modules: ", message), path)) }
    }

    skill expand(path, included, stack) {
        (contains(stack, path) == yes) { out load_error(path, "cyclic import involving ", included) }
        (contains(included, path) == yes) { out SalticLoad { ast = parser_group1("program") included = included diagnostics = [] } }
        @next_included = core.group.add(included, path)
        @source = core.file.read(path) rescue |error| {
            out load_error(path, "module not found at ", next_included)
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
                    @plain = strip_loc(item)
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
                                        @core_path = join_path(join_path(root, "core"), core.group.item(core_files, core_index))
                                        @loaded = expand(core_path, next_included, next_stack)
                                        next_included = loaded.included
                                        (parser_has_diagnostics(loaded.diagnostics) == yes) { diagnostics = loaded.diagnostics active = no }
                                        (active == yes) { output = parser_append_tail(output, loaded.ast, 1) }
                                        core_index = core_index + 1
                                    }
                                }
                            }
                        }
                        (is_core == no) {
                            @module_path = resolve_module(path, parts)
                            @loaded = expand(module_path, next_included, next_stack)
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


    skill load(path) {
        out expand(path, [], [])
    }

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

skill parser_diagnostic(path, line, col, message) {
    @where = core.str.add(path, ":")
    where = core.str.add(where, core.num.text(line))
    where = core.str.add(where, ":")
    where = core.str.add(where, core.num.text(col))
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

skill parser_lex(source, path) {
    @lexer = SalticLexer()
    lexer.source = source
    lexer.path = path
    out lexer.scan()
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

skill parser_append_tail(head, tail, start) {
    @result = head
    @cursor = start
    @count = core.group.count(tail)
    drum (count) {
        (cursor < count) { result = core.group.add(result, core.group.item(tail, cursor)) cursor = cursor + 1 }
    }
    out result
}

skill parser_parse_tokens_mode(tokens, path, locations) {
    @cursor = SalticCursor()
    cursor.tokens = tokens
    cursor.path = path
    @parser = SalticParser()
    parser.cursor = cursor
    parser.locations = locations
    out parser.parse_tokens()
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

skill parser_load_file(path, root) {
    @loader = SalticLoader()
    loader.root = root
    out loader.load(path)
}

skill parser_load_file_loc(path, root) {
    @loader = SalticLoader()
    loader.root = root
    loader.locations = yes
    out loader.load(path)
}

program(path) {
    @parsed = parser_load_file(path, ".")
    @diagnostic_count = core.group.count(parsed.diagnostics)

    core.io.show("ast items: ", core.group.count(parsed.ast))
    core.io.show("diagnostics: ", diagnostic_count)

    (diagnostic_count > 0) {
        out error.ParseFailed
    }

    out none
}
