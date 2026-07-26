use core
use token
use s.make.compiler.diagnostic

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
