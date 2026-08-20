use core

CompilerSymbol = Box {
    name = ""
    kind = ""
    node = []
    value = 0
    text = ""
}

CompilerFunction = Box {
    name = ""
    slots = []
    end = ""
    subject = ""
    types = []
    next_drum = 1
}

CompilerNames = Box {
    names = []
    next_drum = 1
}

CompilerOutput = Box {
    chunks = ["", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""]
}

CompilerState = Box {
    ast = []
    lines = CompilerOutput {}
    data = []
    strings = []
    serial = 0
    constants = []
    boxes = []
    enums = []
    variants = []
    errors = []
    fields = []
    skills = []
    entry = []
    current_function = CompilerFunction {}
    next_enum_id = 1
    next_field_id = 1
}

COMPILER_TAG_NUMBER = 0
COMPILER_TAG_ANSWER = 1
COMPILER_TAG_NONE = 2
COMPILER_TAG_STRING = 3
COMPILER_TAG_GROUP = 4
COMPILER_TAG_BOX = 5
COMPILER_TAG_ENUM = 6
COMPILER_TAG_ERROR = 7

COMPILER_NO = COMPILER_TAG_ANSWER
COMPILER_YES = 8 + COMPILER_TAG_ANSWER
COMPILER_NONE = COMPILER_TAG_NONE
COMPILER_PRINTABLE = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"

skill compiler_plain(node) {
    (core.group.count(node) == 4) {
        (core.group.item(node, 0) == "loc") { out core.group.item(node, 3) }
    }
    out node
}

skill compiler_tag(node) {
    out core.group.item(compiler_plain(node), 0)
}

skill compiler_part(node, index) {
    out core.group.item(compiler_plain(node), index)
}

skill compiler_symbol_find(symbols, name) {
    @result = CompilerSymbol {}
    @index = 0
    @count = core.group.count(symbols)
    drum (count) {
        (index < count) {
            @item = core.group.item(symbols, index)
            (item.name == name) { result = item }
            index = index + 1
        }
    }
    out result
}

skill compiler_symbol_has(symbols, name) {
    @item = compiler_symbol_find(symbols, name)
    out core.str.len(item.name) > 0
}

skill compiler_symbol_add(symbols, name, kind, node, value) {
    out core.group.add(symbols, CompilerSymbol { name = name kind = kind node = node value = value })
}

skill compiler_type_find(types, name) {
    out compiler_symbol_find(types, name)
}

skill compiler_type_set(types, name, type) {
    @result = []
    @found = no
    @index = 0
    @count = core.group.count(types)
    drum (count) {
        (index < count) {
            @item = core.group.item(types, index)
            @next_type = item.text
            (item.name == name) { next_type = type found = yes }
            result = core.group.add(result, CompilerSymbol { name = item.name kind = "type" text = next_type })
            index = index + 1
        }
    }
    (found == no) { result = core.group.add(result, CompilerSymbol { name = name kind = "type" text = type }) }
    out result
}

skill compiler_output_add(output, text) {
    @carry = text
    @chunks = []
    @index = 0
    @count = core.group.count(output.chunks)
    @active = yes
    drum (count) {
        @chunk = core.group.item(output.chunks, index)
        @handling = active
        (handling == no) { chunks = core.group.add(chunks, chunk) }
        (handling == yes) {
            (core.str.len(chunk) == 0) {
                chunks = core.group.add(chunks, carry)
                active = no
            }
            (core.str.len(chunk) > 0) {
                chunks = core.group.add(chunks, "")
                carry = core.str.add(chunk, carry)
            }
        }
        index = index + 1
    }
    (active == yes) { chunks = core.group.add(chunks, carry) }
    out CompilerOutput { chunks = chunks }
}

skill compiler_output_text(output) {
    @result = ""
    @count = core.group.count(output.chunks)
    @index = count - 1
    drum (count) {
        @chunk = core.group.item(output.chunks, index)
        (core.str.len(chunk) > 0) { result = core.str.add(result, chunk) }
        index = index - 1
    }
    out result
}

skill compiler_emit(compiler, line) {
    compiler.lines = compiler_output_add(compiler.lines, core.str.add(line, "\n"))
    out compiler
}

skill compiler_emit_blank(compiler) {
    out compiler_emit(compiler, "")
}

skill compiler_safe(text) {
    @result = ""
    @index = 0
    @length = core.str.len(text)
    @allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
    drum (length) {
        (index < length) {
            @ch = core.str.at(text, index)
            (core.str.contains(allowed, ch) == yes) { result = core.str.add(result, ch) }
            (core.str.contains(allowed, ch) == no) { result = core.str.add(result, "_") }
            index = index + 1
        }
    }
    out result
}

skill compiler_label(compiler, prefix) {
    @label = core.str.add(".L_", compiler_safe(prefix))
    label = core.str.add(label, "_")
    label = core.str.add(label, core.num.text(compiler.serial))
    compiler.serial = compiler.serial + 1
    out label
}

skill compiler_align16(value) {
    @quotient = value / 16
    (quotient * 16 == value) { out value }
    out (quotient + 1) * 16
}

skill compiler_align8(value) {
    @quotient = value / 8
    (quotient * 8 == value) { out value }
    out (quotient + 1) * 8
}

skill compiler_name_add(names, name) {
    (compiler_symbol_has(names.names, name) == no) { names.names = compiler_symbol_add(names.names, name, "local", [], 0) }
    out names
}

skill compiler_collect_expression_names(names, node) {
    @plain = compiler_plain(node)
    @tag = core.group.item(plain, 0)
    (tag == "binary") {
        names = compiler_collect_expression_names(names, core.group.item(plain, 2))
        names = compiler_collect_expression_names(names, core.group.item(plain, 3))
    }
    (tag == "call") {
        @index = 1
        @count = core.group.count(plain)
        drum (count) {
            (index < count) { names = compiler_collect_expression_names(names, core.group.item(plain, index)) }
            index = index + 1
        }
    }
    (tag == "group") {
        @index = 1
        @count = core.group.count(plain)
        drum (count) {
            (index < count) { names = compiler_collect_expression_names(names, core.group.item(plain, index)) }
            index = index + 1
        }
    }
    (tag == "box-new") {
        @index = 2
        @count = core.group.count(plain)
        drum (count) {
            (index < count) { names = compiler_collect_expression_names(names, compiler_part(core.group.item(plain, index), 2)) }
            index = index + 1
        }
    }
    (tag == "rescue") {
        names = compiler_collect_expression_names(names, core.group.item(plain, 1))
        names = compiler_name_add(names, core.group.item(plain, 2))
        names = compiler_collect_block_names(names, core.group.item(plain, 3))
    }
    out names
}

skill compiler_collect_statement_names(names, node) {
    @plain = compiler_plain(node)
    @tag = core.group.item(plain, 0)
    (tag == "var") {
        names = compiler_name_add(names, core.group.item(plain, 1))
        names = compiler_collect_expression_names(names, core.group.item(plain, 2))
    }
    (tag == "assign") { names = compiler_collect_expression_names(names, core.group.item(plain, 2)) }
    (tag == "field-assign") {
        names = compiler_collect_expression_names(names, core.group.item(plain, 1))
        names = compiler_collect_expression_names(names, core.group.item(plain, 2))
    }
    (tag == "out") { names = compiler_collect_expression_names(names, core.group.item(plain, 1)) }
    (tag == "expr") { names = compiler_collect_expression_names(names, core.group.item(plain, 1)) }
    (tag == "if") {
        names = compiler_collect_expression_names(names, core.group.item(plain, 1))
        names = compiler_collect_block_names(names, core.group.item(plain, 2))
    }
    (tag == "switch") {
        names = compiler_collect_expression_names(names, core.group.item(plain, 1))
        @index = 2
        @count = core.group.count(plain)
        drum (count) {
            (index < count) { names = compiler_collect_expression_names(names, compiler_part(core.group.item(plain, index), 2)) }
            index = index + 1
        }
    }
    (tag == "drum") {
        @drum_name = core.str.add("$drum:", core.num.text(names.next_drum))
        names.next_drum = names.next_drum + 1
        names = compiler_name_add(names, drum_name)
        names = compiler_collect_expression_names(names, core.group.item(plain, 1))
        names = compiler_collect_block_names(names, core.group.item(plain, 2))
    }
    out names
}

skill compiler_collect_block_names(names, block) {
    @plain = compiler_plain(block)
    @index = 1
    @count = core.group.count(plain)
    drum (count) {
        (index < count) { names = compiler_collect_statement_names(names, core.group.item(plain, index)) }
        index = index + 1
    }
    out names
}

skill compiler_collect_locals(params, body) {
    @names = CompilerNames {}
    @index = 0
    @count = core.group.count(params)
    drum (count) {
        (index < count) { names = compiler_name_add(names, core.group.item(params, index)) }
        index = index + 1
    }
    out compiler_collect_block_names(names, body)
}

skill compiler_make_slots(names) {
    @slots = []
    @slot = 0 - 12
    @index = 0
    @count = core.group.count(names)
    drum (count) {
        (index < count) {
            @item = core.group.item(names, index)
            slots = compiler_symbol_add(slots, item.name, "slot", [], slot)
            slot = slot - 4
            index = index + 1
        }
    }
    out slots
}

skill compiler_slot(compiler, name) {
    @slot = compiler_symbol_find(compiler.current_function.slots, name)
    out slot.value
}

skill compiler_group_prepend(value, group) {
    @result = [value]
    @index = 0
    @count = core.group.count(group)
    drum (count) {
        (index < count) { result = core.group.add(result, core.group.item(group, index)) }
        index = index + 1
    }
    out result
}

skill compiler_group_slice(group, start, end) {
    @result = []
    @index = start
    @count = core.group.count(group)
    drum (count) {
        (index < end) { result = core.group.add(result, core.group.item(group, index)) }
        index = index + 1
    }
    out result
}

skill compiler_push(compiler, register) {
    compiler = compiler_emit(compiler, "  addi sp, sp, -4")
    compiler = compiler_emit(compiler, core.str.add("  sw ", core.str.add(register, ", 0(sp)")))
    out compiler
}

skill compiler_pop(compiler, register) {
    compiler = compiler_emit(compiler, core.str.add("  lw ", core.str.add(register, ", 0(sp)")))
    compiler = compiler_emit(compiler, "  addi sp, sp, 4")
    out compiler
}

skill compiler_load_immediate(compiler, register, value) {
    out compiler_emit(compiler, core.str.add("  li ", core.str.add(register, core.str.add(", ", core.num.text(value)))))
}

skill compiler_field(compiler, name) {
    @field = compiler_symbol_find(compiler.fields, name)
    out field.value
}

skill compiler_render_lines(output) {
    out compiler_output_text(output)
}

skill compiler_collect_box(compiler, item) {
    @name = compiler_part(item, 1)
    compiler.boxes = compiler_symbol_add(compiler.boxes, name, "box", item, 0)
    @index = 2
    @count = core.group.count(compiler_plain(item))
    drum (count) {
        (index < count) {
            @member = compiler_part(item, index)
            (compiler_tag(member) == "field") {
                @field_name = compiler_part(member, 1)
                (compiler_symbol_has(compiler.fields, field_name) == no) {
                    compiler.fields = compiler_symbol_add(compiler.fields, field_name, "field", member, compiler.next_field_id)
                    compiler.next_field_id = compiler.next_field_id + 1
                }
            }
            index = index + 1
        }
    }
    out compiler
}

skill compiler_collect_enum(compiler, item) {
    @name = compiler_part(item, 1)
    compiler.enums = compiler_symbol_add(compiler.enums, name, "enum", item, 0)
    @index = 2
    @count = core.group.count(compiler_plain(item))
    drum (count) {
        (index < count) {
            @variant = compiler_part(item, index)
            @full_name = core.str.add(name, ".")
            full_name = core.str.add(full_name, variant)
            @value = compiler.next_enum_id * 8 + COMPILER_TAG_ENUM
            compiler.variants = compiler_symbol_add(compiler.variants, full_name, "variant", item, value)
            (compiler_symbol_has(compiler.variants, variant) == no) { compiler.variants = compiler_symbol_add(compiler.variants, variant, "variant", item, value) }
            compiler.next_enum_id = compiler.next_enum_id + 1
            index = index + 1
        }
    }
    out compiler
}

skill compiler_collect_top_level(compiler) {
    @index = 1
    @count = core.group.count(compiler.ast)
    drum (count) {
        (index < count) {
            @item = core.group.item(compiler.ast, index)
            @tag = compiler_tag(item)
            (tag == "const") { compiler.constants = compiler_symbol_add(compiler.constants, compiler_part(item, 1), "const", compiler_part(item, 2), 0) }
            (tag == "box") { compiler = compiler_collect_box(compiler, item) }
            (tag == "enum") { compiler = compiler_collect_enum(compiler, item) }
            (tag == "skill") { compiler.skills = compiler_symbol_add(compiler.skills, compiler_part(item, 1), "skill", item, 0) }
            (tag == "entry") { compiler.entry = item }
            index = index + 1
        }
    }
    out compiler
}

skill compiler_header(compiler) {
    compiler = compiler_emit(compiler, ".option norvc")
    compiler = compiler_emit(compiler, ".option norelax")
    compiler = compiler_emit(compiler, ".section .text")
    compiler = compiler_emit(compiler, ".global _start")
    compiler = compiler_emit_blank(compiler)
    out compiler
}

skill compiler_start(compiler) {
    @params = compiler_part(compiler.entry, 1)
    @param_count = core.group.count(params)
    compiler = compiler_emit(compiler, "_start:")
    compiler = compiler_emit(compiler, "  la s1, saltic_heap")
    compiler = compiler_emit(compiler, "  la s2, saltic_heap_end")
    @required = core.num.text(param_count + 1)
    compiler = compiler_emit(compiler, core.str.add("  addi t0, zero, ", required))
    compiler = compiler_emit(compiler, "  blt a0, t0, rt_missing_args")
    @index = 0
    drum (param_count) {
        @offset = core.num.text((index + 1) * 4)
        compiler = compiler_emit(compiler, core.str.add("  lw a0, ", core.str.add(offset, "(a1)")))
        compiler = compiler_emit(compiler, "  call rt_cstring")
        compiler = compiler_emit(compiler, "  addi sp, sp, -4")
        compiler = compiler_emit(compiler, "  sw a0, 0(sp)")
        index = index + 1
    }
    index = 0
    drum (param_count) {
        @register = core.str.add("a", core.num.text(index))
        @offset = core.num.text((param_count - index - 1) * 4)
        compiler = compiler_emit(compiler, core.str.add("  lw ", core.str.add(register, core.str.add(", ", core.str.add(offset, "(sp)")))))
        index = index + 1
    }
    (param_count > 0) { compiler = compiler_emit(compiler, core.str.add("  addi sp, sp, ", core.num.text(param_count * 4))) }
    compiler = compiler_emit(compiler, "  call saltic_program")
    compiler = compiler_emit(compiler, "  andi t0, a0, 7")
    compiler = compiler_emit(compiler, "  addi t1, zero, 7")
    compiler = compiler_emit(compiler, "  sub a0, t0, t1")
    compiler = compiler_emit(compiler, "  sltu a0, zero, a0")
    compiler = compiler_emit(compiler, "  xori a0, a0, 1")
    compiler = compiler_emit(compiler, "  addi a7, zero, 93")
    compiler = compiler_emit(compiler, "  ecall")
    compiler = compiler_emit_blank(compiler)
    out compiler
}

skill compiler_box_field_symbol(compiler, box_name, field_name) {
    @box = compiler_symbol_find(compiler.boxes, box_name)
    @result = CompilerSymbol {}
    @index = 2
    @count = core.group.count(compiler_plain(box.node))
    drum (count) {
        (index < count) {
            @member = compiler_part(box.node, index)
            (compiler_tag(member) == "field") {
                (compiler_part(member, 1) == field_name) { result = CompilerSymbol { name = field_name kind = "field" node = member } }
            }
            index = index + 1
        }
    }
    out result
}

skill compiler_error_value(compiler, name) {
    @error_item = compiler_symbol_find(compiler.errors, name)
    (core.str.len(error_item.name) == 0) {
        @id = core.group.count(compiler.errors) + 1
        compiler.errors = compiler_symbol_add(compiler.errors, name, "error", [], id)
        error_item = compiler_symbol_find(compiler.errors, name)
    }
    out error_item.value * 8 + COMPILER_TAG_ERROR
}

skill compiler_compile_path(compiler, node) {
    @parts = compiler_plain(node)
    @count = core.group.count(parts)
    @name = core.group.item(parts, 1)
    (name == "error") {
        (count == 3) { out compiler_load_immediate(compiler, "a0", compiler_error_value(compiler, core.group.item(parts, 2))) }
    }
    (count == 3) {
        (compiler_symbol_has(compiler.enums, name) == yes) {
            @full_name = core.str.add(name, ".")
            full_name = core.str.add(full_name, core.group.item(parts, 2))
            @variant = compiler_symbol_find(compiler.variants, full_name)
            out compiler_load_immediate(compiler, "a0", variant.value)
        }
    }
    (compiler_symbol_has(compiler.current_function.slots, name) == yes) {
        @slot = compiler_slot(compiler, name)
        compiler = compiler_emit(compiler, core.str.add("  lw a0, ", core.str.add(core.num.text(slot), "(s0)")))
    }
    (compiler_symbol_has(compiler.current_function.slots, name) == no) {
        @constant = compiler_symbol_find(compiler.constants, name)
        (core.str.len(constant.name) > 0) { compiler = compiler_expression(compiler, constant.node) }
        (core.str.len(constant.name) == 0) {
            @subject_field = compiler_box_field_symbol(compiler, compiler.current_function.subject, name)
            (core.str.len(subject_field.name) > 0) {
                @self_slot = compiler_slot(compiler, "$self")
                compiler = compiler_emit(compiler, core.str.add("  lw a0, ", core.str.add(core.num.text(self_slot), "(s0)")))
                compiler = compiler_push(compiler, "a0")
                compiler = compiler_load_immediate(compiler, "a1", compiler_field(compiler, name))
                compiler = compiler_pop(compiler, "a0")
                compiler = compiler_emit(compiler, "  call rt_box_get")
            }
        }
    }
    @index = 2
    drum (count) {
        (index < count) {
            compiler = compiler_push(compiler, "a0")
            compiler = compiler_load_immediate(compiler, "a1", compiler_field(compiler, core.group.item(parts, index)))
            compiler = compiler_pop(compiler, "a0")
            compiler = compiler_emit(compiler, "  call rt_box_get")
            index = index + 1
        }
    }
    out compiler
}

skill compiler_compile_binary(compiler, operator, left, right) {
    compiler = compiler_expression(compiler, left)
    compiler = compiler_push(compiler, "a0")
    compiler = compiler_expression(compiler, right)
    compiler = compiler_emit(compiler, "  addi a1, a0, 0")
    compiler = compiler_pop(compiler, "a0")
    @target = ""
    (operator == "+") { target = "rt_add" }
    (operator == "-") { target = "rt_sub" }
    (operator == "*") { target = "rt_mul" }
    (operator == "/") { target = "rt_div" }
    (operator == "==") { target = "rt_equal" }
    (operator == ">") { target = "rt_greater" }
    (operator == "<") { target = "rt_less" }
    out compiler_emit(compiler, core.str.add("  call ", target))
}

skill compiler_compile_rescue(compiler, node) {
    @plain = compiler_plain(node)
    @done = compiler_label(compiler, "rescue_done")
    compiler = compiler_expression(compiler, core.group.item(plain, 1))
    compiler = compiler_emit(compiler, "  andi t0, a0, 7")
    compiler = compiler_emit(compiler, core.str.add("  addi t1, zero, ", core.num.text(COMPILER_TAG_ERROR)))
    compiler = compiler_emit(compiler, core.str.add("  bne t0, t1, ", done))
    @slot = compiler_slot(compiler, core.group.item(plain, 2))
    compiler = compiler_emit(compiler, core.str.add("  sw a0, ", core.str.add(core.num.text(slot), "(s0)")))
    compiler = compiler_compile_block(compiler, core.group.item(plain, 3), yes)
    out compiler_emit(compiler, core.str.add(done, ":"))
}

skill compiler_box_has_skill(compiler, box_name, skill_name) {
    @box = compiler_symbol_find(compiler.boxes, box_name)
    @found = no
    @index = 2
    @count = core.group.count(compiler_plain(box.node))
    drum (count) {
        (index < count) {
            @member = compiler_part(box.node, index)
            (compiler_tag(member) == "subject-skill") {
                (compiler_part(member, 1) == skill_name) { found = yes }
            }
            index = index + 1
        }
    }
    out found
}

skill compiler_infer_type(compiler, node) {
    @plain = compiler_plain(node)
    @tag = core.group.item(plain, 0)
    (tag == "box-new") { out core.str.add("box:", core.group.item(plain, 1)) }
    (tag == "path") {
        @name = core.group.item(plain, 1)
        @type_item = compiler_type_find(compiler.current_function.types, name)
        @type = type_item.text
        (core.group.count(plain) == 2) { out type }
        (core.str.starts_with(type, "box:") == yes) {
            @field = compiler_box_field_symbol(compiler, core.str.slice(type, 4, core.str.len(type)), core.group.item(plain, 2))
            (core.str.len(field.name) > 0) {
                @value = compiler_part(field.node, 2)
                (compiler_tag(value) == "box-new") { out core.str.add("box:", compiler_part(value, 1)) }
            }
        }
        out "unknown"
    }
    (tag == "call") {
        @callee = compiler_plain(core.group.item(plain, 1))
        (compiler_tag(callee) == "path") {
            (core.group.count(callee) == 2) {
                @name = core.group.item(callee, 1)
                (compiler_symbol_has(compiler.boxes, name) == yes) { out core.str.add("box:", name) }
            }
        }
        out "unknown"
    }
    (tag == "rescue") { out compiler_infer_type(compiler, core.group.item(plain, 1)) }
    out "unknown"
}

skill compiler_path_text(path) {
    @plain = compiler_plain(path)
    @result = core.group.item(plain, 1)
    @index = 2
    @count = core.group.count(plain)
    drum (count) {
        (index < count) {
            result = core.str.add(result, ".")
            result = core.str.add(result, core.group.item(plain, index))
            index = index + 1
        }
    }
    out result
}

skill compiler_call_arguments(node) {
    @plain = compiler_plain(node)
    out compiler_group_slice(plain, 2, core.group.count(plain))
}

skill compiler_compile_arguments(compiler, args) {
    @index = 0
    @count = core.group.count(args)
    drum (count) {
        (index < count) {
            compiler = compiler_expression(compiler, core.group.item(args, index))
            compiler = compiler_push(compiler, "a0")
            index = index + 1
        }
    }
    index = 0
    drum (count) {
        (index < count) {
            @register = core.str.add("a", core.num.text(index))
            @offset = core.num.text((count - index - 1) * 4)
            compiler = compiler_emit(compiler, core.str.add("  lw ", core.str.add(register, core.str.add(", ", core.str.add(offset, "(sp)")))))
            index = index + 1
        }
    }
    (count > 0) { compiler = compiler_emit(compiler, core.str.add("  addi sp, sp, ", core.num.text(count * 4))) }
    out compiler
}

skill compiler_compile_show(compiler, args) {
    @index = 0
    @count = core.group.count(args)
    drum (count) {
        (index < count) {
            compiler = compiler_expression(compiler, core.group.item(args, index))
            compiler = compiler_emit(compiler, "  call rt_show")
            index = index + 1
        }
    }
    compiler = compiler_emit(compiler, "  call rt_newline")
    out compiler_load_immediate(compiler, "a0", COMPILER_NONE)
}

skill compiler_intrinsic(name) {
    (name == "core.group.count") { out "rt_group_count" }
    (name == "core.group.at") { out "rt_group_at" }
    (name == "core.group.item") { out "rt_group_at" }
    (name == "core.group.add") { out "rt_group_add" }
    (name == "core.group.append") { out "rt_group_add" }
    (name == "core.file.read") { out "rt_file_read" }
    (name == "core.file.write") { out "rt_file_write" }
    (name == "core.str.line_count") { out "rt_line_count" }
    (name == "core.str.add") { out "rt_string_add" }
    (name == "core.str.join") { out "rt_string_add" }
    (name == "core.str.len") { out "rt_string_len" }
    (name == "core.str.at") { out "rt_string_at" }
    (name == "core.str.slice") { out "rt_string_slice" }
    (name == "core.str.contains") { out "rt_string_contains" }
    (name == "core.str.starts_with") { out "rt_string_starts_with" }
    (name == "core.str.ends_with") { out "rt_string_ends_with" }
    (name == "core.str.lower") { out "rt_string_lower" }
    (name == "core.str.upper") { out "rt_string_upper" }
    (name == "core.num.text") { out "rt_number_text" }
    out ""
}

skill compiler_ascii_code(ch) {
    (ch == "\n") { out 10 }
    (ch == "\t") { out 9 }
    @index = 0
    @length = core.str.len(COMPILER_PRINTABLE)
    @code = 0
    drum (length) {
        (index < length) {
            (core.str.at(COMPILER_PRINTABLE, index) == ch) { code = index + 32 }
            index = index + 1
        }
    }
    out code
}

skill compiler_string_find(compiler, text) {
    @result = CompilerSymbol {}
    @index = 0
    @count = core.group.count(compiler.strings)
    drum (count) {
        (index < count) {
            @item = core.group.item(compiler.strings, index)
            (item.text == text) { result = item }
            index = index + 1
        }
    }
    out result
}

skill compiler_string_label(compiler, text) {
    @known = compiler_string_find(compiler, text)
    (core.str.len(known.name) > 0) { out known.name }
    @label = compiler_label(compiler, "string")
    @values = CompilerOutput()
    @index = 0
    @length = core.str.len(text)
    drum (length) {
        (index < length) {
            (index > 0) { values = compiler_output_add(values, ", ") }
            values = compiler_output_add(values, core.num.text(compiler_ascii_code(core.str.at(text, index))))
            index = index + 1
        }
    }
    (length > 0) { values = compiler_output_add(values, ", ") }
    values = compiler_output_add(values, "0")
    @values_text = compiler_output_text(values)
    @datum = core.str.add(label, ":\n  .word ")
    datum = core.str.add(datum, core.num.text(length))
    datum = core.str.add(datum, "\n  .byte ")
    datum = core.str.add(datum, values_text)
    datum = core.str.add(datum, "\n  .balign 8")
    compiler.data = core.group.add(compiler.data, datum)
    compiler.strings = core.group.add(compiler.strings, CompilerSymbol { name = label kind = "string" text = text })
    out label
}

skill compiler_compile_group(compiler, items) {
    @index = 0
    @count = core.group.count(items)
    drum (count) {
        (index < count) {
            compiler = compiler_expression(compiler, core.group.item(items, index))
            compiler = compiler_push(compiler, "a0")
            index = index + 1
        }
    }
    compiler = compiler_load_immediate(compiler, "a0", compiler_align8(4 + count * 4))
    compiler = compiler_emit(compiler, "  call rt_alloc")
    compiler = compiler_emit(compiler, core.str.add("  addi t3, zero, ", core.num.text(count)))
    compiler = compiler_emit(compiler, "  sw t3, 0(a0)")
    index = 0
    drum (count) {
        (index < count) {
            @source_offset = core.num.text((count - index - 1) * 4)
            @target_offset = core.num.text(4 + index * 4)
            compiler = compiler_emit(compiler, core.str.add("  lw t0, ", core.str.add(source_offset, "(sp)")))
            compiler = compiler_emit(compiler, core.str.add("  sw t0, ", core.str.add(target_offset, "(a0)")))
            index = index + 1
        }
    }
    (count > 0) { compiler = compiler_emit(compiler, core.str.add("  addi sp, sp, ", core.num.text(count * 4))) }
    out compiler_emit(compiler, core.str.add("  ori a0, a0, ", core.num.text(COMPILER_TAG_GROUP)))
}

skill compiler_box_override(overrides, field_name) {
    @result = []
    @index = 0
    @count = core.group.count(overrides)
    drum (count) {
        (index < count) {
            @field = compiler_plain(core.group.item(overrides, index))
            (core.group.item(field, 1) == field_name) { result = core.group.item(field, 2) }
            index = index + 1
        }
    }
    out result
}

skill compiler_compile_box(compiler, name, overrides) {
    @model = compiler_symbol_find(compiler.boxes, name)
    @fields = []
    @index = 2
    @member_count = core.group.count(compiler_plain(model.node))
    drum (member_count) {
        (index < member_count) {
            @member = compiler_part(model.node, index)
            (compiler_tag(member) == "field") { fields = core.group.add(fields, member) }
            index = index + 1
        }
    }
    @count = core.group.count(fields)
    index = 0
    drum (count) {
        (index < count) {
            @field = core.group.item(fields, index)
            @value = compiler_box_override(overrides, compiler_part(field, 1))
            (core.group.count(value) == 0) { value = compiler_part(field, 2) }
            compiler = compiler_expression(compiler, value)
            compiler = compiler_push(compiler, "a0")
            index = index + 1
        }
    }
    compiler = compiler_load_immediate(compiler, "a0", compiler_align8(4 + count * 8))
    compiler = compiler_emit(compiler, "  call rt_alloc")
    compiler = compiler_emit(compiler, core.str.add("  addi t3, zero, ", core.num.text(count)))
    compiler = compiler_emit(compiler, "  sw t3, 0(a0)")
    index = 0
    drum (count) {
        (index < count) {
            @field = core.group.item(fields, index)
            @field_id = compiler_field(compiler, compiler_part(field, 1))
            compiler = compiler_load_immediate(compiler, "t0", field_id)
            compiler = compiler_emit(compiler, core.str.add("  sw t0, ", core.str.add(core.num.text(4 + index * 8), "(a0)")))
            compiler = compiler_emit(compiler, core.str.add("  lw t0, ", core.str.add(core.num.text((count - index - 1) * 4), "(sp)")))
            compiler = compiler_emit(compiler, core.str.add("  sw t0, ", core.str.add(core.num.text(8 + index * 8), "(a0)")))
            index = index + 1
        }
    }
    (count > 0) { compiler = compiler_emit(compiler, core.str.add("  addi sp, sp, ", core.num.text(count * 4))) }
    out compiler_emit(compiler, core.str.add("  ori a0, a0, ", core.num.text(COMPILER_TAG_BOX)))
}

skill compiler_compile_call(compiler, node) {
    @plain = compiler_plain(node)
    @callee = compiler_plain(core.group.item(plain, 1))
    @args = compiler_call_arguments(node)
    @name = compiler_path_text(callee)
    (name == "core.io.show") { out compiler_compile_show(compiler, args) }
    (core.group.count(callee) == 2) {
        @short_name = core.group.item(callee, 1)
        (core.str.len(compiler.current_function.subject) > 0) {
            (compiler_box_has_skill(compiler, compiler.current_function.subject, short_name) == yes) {
                @with_self = compiler_group_prepend(["path", "$self"], args)
                compiler = compiler_compile_arguments(compiler, with_self)
                @target = core.str.add(compiler.current_function.subject, ".")
                target = core.str.add(target, short_name)
                out compiler_emit(compiler, core.str.add("  call saltic_", compiler_safe(target)))
            }
        }
        (compiler_symbol_has(compiler.boxes, short_name) == yes) { out compiler_compile_box(compiler, short_name, []) }
    }
    (core.group.count(callee) == 3) {
        @receiver = ["path", core.group.item(callee, 1)]
        @receiver_type = compiler_infer_type(compiler, receiver)
        (core.str.starts_with(receiver_type, "box:") == yes) {
            @box_name = core.str.slice(receiver_type, 4, core.str.len(receiver_type))
            @method = core.group.item(callee, 2)
            (compiler_box_has_skill(compiler, box_name, method) == yes) {
                @with_receiver = compiler_group_prepend(receiver, args)
                compiler = compiler_compile_arguments(compiler, with_receiver)
                @target = core.str.add(box_name, ".")
                target = core.str.add(target, method)
                out compiler_emit(compiler, core.str.add("  call saltic_", compiler_safe(target)))
            }
        }
    }
    @target = compiler_intrinsic(name)
    (core.str.len(target) == 0) {
        (compiler_symbol_has(compiler.skills, name) == yes) { target = core.str.add("saltic_", compiler_safe(name)) }
    }
    compiler = compiler_compile_arguments(compiler, args)
    out compiler_emit(compiler, core.str.add("  call ", target))
}

skill compiler_expression(compiler, node) {
    @plain = compiler_plain(node)
    @tag = core.group.item(plain, 0)
    (tag == "number") { out compiler_load_immediate(compiler, "a0", core.group.item(plain, 1) * 8) }
    (tag == "string") {
        @label = compiler_string_label(compiler, core.group.item(plain, 1))
        compiler = compiler_emit(compiler, core.str.add("  la a0, ", label))
        out compiler_emit(compiler, core.str.add("  ori a0, a0, ", core.num.text(COMPILER_TAG_STRING)))
    }
    (tag == "answer") {
        (core.group.item(plain, 1) == "yes") { out compiler_load_immediate(compiler, "a0", COMPILER_YES) }
        out compiler_load_immediate(compiler, "a0", COMPILER_NO)
    }
    (tag == "none") { out compiler_load_immediate(compiler, "a0", COMPILER_NONE) }
    (tag == "path") { out compiler_compile_path(compiler, node) }
    (tag == "binary") { out compiler_compile_binary(compiler, core.group.item(plain, 1), core.group.item(plain, 2), core.group.item(plain, 3)) }
    (tag == "call") { out compiler_compile_call(compiler, node) }
    (tag == "group") { out compiler_compile_group(compiler, compiler_group_slice(plain, 1, core.group.count(plain))) }
    (tag == "box-new") { out compiler_compile_box(compiler, core.group.item(plain, 1), compiler_group_slice(plain, 2, core.group.count(plain))) }
    (tag == "rescue") { out compiler_compile_rescue(compiler, node) }
    (tag == "enum-value") {
        @variant = compiler_symbol_find(compiler.variants, core.group.item(plain, 1))
        out compiler_load_immediate(compiler, "a0", variant.value)
    }
    out compiler
}

skill compiler_compile_block(compiler, block, keep) {
    @plain = compiler_plain(block)
    @index = 1
    @count = core.group.count(plain)
    drum (count) {
        (index < count) {
            @last = no
            (keep == yes) {
                (index + 1 == count) { last = yes }
            }
            compiler = compiler_compile_statement(compiler, core.group.item(plain, index), last)
            index = index + 1
        }
    }
    (keep == yes) {
        (count == 1) { compiler = compiler_load_immediate(compiler, "a0", COMPILER_NONE) }
    }
    out compiler
}

skill compiler_compile_statement(compiler, node, keep) {
    @plain = compiler_plain(node)
    @tag = core.group.item(plain, 0)
    (tag == "var") {
        @value = core.group.item(plain, 2)
        compiler = compiler_expression(compiler, value)
        @slot = compiler_slot(compiler, core.group.item(plain, 1))
        compiler = compiler_emit(compiler, core.str.add("  sw a0, ", core.str.add(core.num.text(slot), "(s0)")))
        @type = compiler_infer_type(compiler, value)
        @known = compiler_type_find(compiler.current_function.types, core.group.item(plain, 1))
        (type == "unknown") {
            (core.str.len(known.name) == 0) { compiler.current_function.types = compiler_type_set(compiler.current_function.types, core.group.item(plain, 1), type) }
        }
        (type == "unknown") { out compiler }
        compiler.current_function.types = compiler_type_set(compiler.current_function.types, core.group.item(plain, 1), type)
        out compiler
    }
    (tag == "assign") {
        @value = core.group.item(plain, 2)
        compiler = compiler_expression(compiler, value)
        @slot = compiler_slot(compiler, core.group.item(plain, 1))
        compiler = compiler_emit(compiler, core.str.add("  sw a0, ", core.str.add(core.num.text(slot), "(s0)")))
        @type = compiler_infer_type(compiler, value)
        @known = compiler_type_find(compiler.current_function.types, core.group.item(plain, 1))
        (type == "unknown") {
            (core.str.len(known.name) == 0) { compiler.current_function.types = compiler_type_set(compiler.current_function.types, core.group.item(plain, 1), type) }
        }
        (type == "unknown") { out compiler }
        compiler.current_function.types = compiler_type_set(compiler.current_function.types, core.group.item(plain, 1), type)
        out compiler
    }
    (tag == "field-assign") {
        @target = compiler_plain(core.group.item(plain, 1))
        @part_count = core.group.count(target)
        @base = compiler_group_slice(target, 0, part_count - 1)
        compiler = compiler_expression(compiler, base)
        compiler = compiler_push(compiler, "a0")
        compiler = compiler_expression(compiler, core.group.item(plain, 2))
        compiler = compiler_emit(compiler, "  addi a2, a0, 0")
        compiler = compiler_pop(compiler, "a0")
        compiler = compiler_load_immediate(compiler, "a1", compiler_field(compiler, core.group.item(target, part_count - 1)))
        out compiler_emit(compiler, "  call rt_box_set")
    }
    (tag == "out") {
        compiler = compiler_expression(compiler, core.group.item(plain, 1))
        out compiler_emit(compiler, core.str.add("  j ", compiler.current_function.end))
    }
    (tag == "expr") { out compiler_expression(compiler, core.group.item(plain, 1)) }
    (tag == "if") {
        @end = compiler_label(compiler, "if_end")
        compiler = compiler_expression(compiler, core.group.item(plain, 1))
        compiler = compiler_emit(compiler, core.str.add("  addi t0, zero, ", core.num.text(COMPILER_NO)))
        compiler = compiler_emit(compiler, core.str.add("  beq a0, t0, ", end))
        compiler = compiler_emit(compiler, core.str.add("  addi t0, zero, ", core.num.text(COMPILER_NONE)))
        compiler = compiler_emit(compiler, core.str.add("  beq a0, t0, ", end))
        compiler = compiler_emit(compiler, core.str.add("  beq a0, zero, ", end))
        compiler = compiler_compile_block(compiler, core.group.item(plain, 2), keep)
        out compiler_emit(compiler, core.str.add(end, ":"))
    }
    (tag == "switch") {
        @end = compiler_label(compiler, "switch_end")
        compiler = compiler_expression(compiler, core.group.item(plain, 1))
        compiler = compiler_emit(compiler, "  addi t2, a0, 0")
        @index = 2
        @count = core.group.count(plain)
        drum (count) {
            (index < count) {
                @case_node = compiler_plain(core.group.item(plain, index))
                @next = compiler_label(compiler, "case_next")
                @variant = compiler_symbol_find(compiler.variants, core.group.item(case_node, 1))
                compiler = compiler_load_immediate(compiler, "t0", variant.value)
                compiler = compiler_emit(compiler, core.str.add("  bne t2, t0, ", next))
                compiler = compiler_expression(compiler, core.group.item(case_node, 2))
                compiler = compiler_emit(compiler, core.str.add("  j ", end))
                compiler = compiler_emit(compiler, core.str.add(next, ":"))
                index = index + 1
            }
        }
        out compiler_emit(compiler, core.str.add(end, ":"))
    }
    (tag == "drum") {
        @drum_name = core.str.add("$drum:", core.num.text(compiler.current_function.next_drum))
        compiler.current_function.next_drum = compiler.current_function.next_drum + 1
        @counter = compiler_slot(compiler, drum_name)
        @start = compiler_label(compiler, "drum")
        @end = compiler_label(compiler, "drum_end")
        compiler = compiler_expression(compiler, core.group.item(plain, 1))
        compiler = compiler_emit(compiler, "  srai a0, a0, 3")
        compiler = compiler_emit(compiler, core.str.add("  sw a0, ", core.str.add(core.num.text(counter), "(s0)")))
        compiler = compiler_emit(compiler, core.str.add(start, ":"))
        compiler = compiler_emit(compiler, core.str.add("  lw t0, ", core.str.add(core.num.text(counter), "(s0)")))
        compiler = compiler_emit(compiler, core.str.add("  beq t0, zero, ", end))
        compiler = compiler_emit(compiler, "  addi t0, t0, -1")
        compiler = compiler_emit(compiler, core.str.add("  sw t0, ", core.str.add(core.num.text(counter), "(s0)")))
        compiler = compiler_compile_block(compiler, core.group.item(plain, 2), no)
        compiler = compiler_emit(compiler, core.str.add("  j ", start))
        out compiler_emit(compiler, core.str.add(end, ":"))
    }
    out compiler
}

skill compiler_compile_function(compiler, name, params, body, subject) {
    @locals = compiler_collect_locals(params, body)
    @local_count = core.group.count(locals.names)
    @frame = compiler_align16((local_count + 2) * 4)
    @slots = compiler_make_slots(locals.names)
    @end = compiler_label(compiler, core.str.add(name, "_return"))
    @types = []
    @type_index = 0
    @type_count = core.group.count(params)
    drum (type_count) {
        (type_index < type_count) {
            types = compiler_type_set(types, core.group.item(params, type_index), "unknown")
            type_index = type_index + 1
        }
    }
    (core.str.len(subject) > 0) { types = compiler_type_set(types, "$self", core.str.add("box:", subject)) }
    compiler.current_function = CompilerFunction { name = name slots = slots end = end subject = subject types = types }
    compiler = compiler_emit(compiler, core.str.add("saltic_", core.str.add(compiler_safe(name), ":")))
    compiler = compiler_emit(compiler, core.str.add("  addi sp, sp, -", core.num.text(frame)))
    compiler = compiler_emit(compiler, core.str.add("  sw ra, ", core.str.add(core.num.text(frame - 4), "(sp)")))
    compiler = compiler_emit(compiler, core.str.add("  sw s0, ", core.str.add(core.num.text(frame - 8), "(sp)")))
    compiler = compiler_emit(compiler, core.str.add("  addi s0, sp, ", core.num.text(frame)))
    @index = 0
    @param_count = core.group.count(params)
    drum (param_count) {
        (index < param_count) {
            @register = core.str.add("a", core.num.text(index))
            @slot = compiler_slot(compiler, core.group.item(params, index))
            compiler = compiler_emit(compiler, core.str.add("  sw ", core.str.add(register, core.str.add(", ", core.str.add(core.num.text(slot), "(s0)")))))
            index = index + 1
        }
    }
    compiler = compiler_compile_block(compiler, body, no)
    compiler = compiler_emit(compiler, core.str.add("  addi a0, zero, ", core.num.text(COMPILER_NONE)))
    compiler = compiler_emit(compiler, core.str.add("  j ", end))
    compiler = compiler_emit(compiler, core.str.add(end, ":"))
    compiler = compiler_emit(compiler, "  lw ra, -4(s0)")
    compiler = compiler_emit(compiler, "  lw t0, -8(s0)")
    compiler = compiler_emit(compiler, "  addi sp, s0, 0")
    compiler = compiler_emit(compiler, "  addi s0, t0, 0")
    compiler = compiler_emit(compiler, "  jalr zero, 0(ra)")
    compiler = compiler_emit_blank(compiler)
    compiler.current_function = CompilerFunction {}
    out compiler
}

skill compiler_compile_functions(compiler) {
    @index = 0
    @count = core.group.count(compiler.skills)
    drum (count) {
        (index < count) {
            @symbol = core.group.item(compiler.skills, index)
            @skill_node = symbol.node
            compiler = compiler_compile_function(compiler, symbol.name, compiler_part(skill_node, 2), compiler_part(skill_node, 3), "")
            index = index + 1
        }
    }
    @box_index = 0
    @box_count = core.group.count(compiler.boxes)
    drum (box_count) {
        (box_index < box_count) {
            @box = core.group.item(compiler.boxes, box_index)
            @member_index = 2
            @member_count = core.group.count(compiler_plain(box.node))
            drum (member_count) {
                (member_index < member_count) {
                    @member = compiler_part(box.node, member_index)
                    (compiler_tag(member) == "subject-skill") {
                        @name = core.str.add(box.name, ".")
                        name = core.str.add(name, compiler_part(member, 1))
                        @params = compiler_group_prepend("$self", compiler_part(member, 2))
                        compiler = compiler_compile_function(compiler, name, params, compiler_part(member, 3), box.name)
                    }
                    member_index = member_index + 1
                }
            }
            box_index = box_index + 1
        }
    }
    compiler = compiler_compile_function(compiler, "program", compiler_part(compiler.entry, 1), compiler_part(compiler.entry, 2), "")
    out compiler
}

skill compiler_join_data(data) {
    @result = ""
    @index = 0
    @count = core.group.count(data)
    drum (count) {
        (index < count) {
            (index > 0) { result = core.str.add(result, "\n") }
            result = core.str.add(result, core.group.item(data, index))
            index = index + 1
        }
    }
    out result
}

skill compiler_runtime_assembly() {
    out "
rt_alloc:
  addi a0, a0, 7
  andi a0, a0, -8
  add t0, s1, a0
  bgtu t0, s2, rt_out_of_memory
  addi a0, s1, 0
  addi s1, t0, 0
  jalr zero, 0(ra)

rt_add:
  add a0, a0, a1
  jalr zero, 0(ra)
rt_sub:
  sub a0, a0, a1
  jalr zero, 0(ra)
rt_mul:
  srai a0, a0, 3
  srai a1, a1, 3
  addi t0, zero, 0
  addi t1, a1, 0
  bge t1, zero, .L_mul_positive
  sub t1, zero, t1
  sub a0, zero, a0
.L_mul_positive:
  beq t1, zero, .L_mul_done
.L_mul_loop:
  andi t2, t1, 1
  beq t2, zero, .L_mul_skip
  add t0, t0, a0
.L_mul_skip:
  slli a0, a0, 1
  srli t1, t1, 1
  bne t1, zero, .L_mul_loop
.L_mul_done:
  slli a0, t0, 3
  jalr zero, 0(ra)
rt_div:
  srai a0, a0, 3
  srai a1, a1, 3
  beq a1, zero, rt_division_by_zero
  addi t0, zero, 0
  addi t1, zero, 0
  bge a0, zero, .L_div_left
  sub a0, zero, a0
  xori t1, t1, 1
.L_div_left:
  bge a1, zero, .L_div_right
  sub a1, zero, a1
  xori t1, t1, 1
.L_div_right:
  bltu a0, a1, .L_div_done
.L_div_loop:
  sub a0, a0, a1
  addi t0, t0, 1
  bgeu a0, a1, .L_div_loop
.L_div_done:
  beq t1, zero, .L_div_encode
  sub t0, zero, t0
.L_div_encode:
  slli a0, t0, 3
  jalr zero, 0(ra)

rt_equal:
  beq a0, a1, .L_equal_yes
  andi t0, a0, 7
  andi t1, a1, 7
  bne t0, t1, .L_equal_no
  addi t2, zero, 3
  bne t0, t2, .L_equal_no
  andi a0, a0, -8
  andi a1, a1, -8
  lw t0, 0(a0)
  lw t1, 0(a1)
  bne t0, t1, .L_equal_no
  addi t2, zero, 0
.L_equal_string:
  beq t2, t0, .L_equal_yes
  add t3, a0, t2
  add t4, a1, t2
  lbu t3, 4(t3)
  lbu t4, 4(t4)
  bne t3, t4, .L_equal_no
  addi t2, t2, 1
  j .L_equal_string
.L_equal_yes:
  addi a0, zero, 9
  jalr zero, 0(ra)
.L_equal_no:
  addi a0, zero, 1
  jalr zero, 0(ra)
rt_less:
  srai a0, a0, 3
  srai a1, a1, 3
  blt a0, a1, .L_less_yes
  addi a0, zero, 1
  jalr zero, 0(ra)
.L_less_yes:
  addi a0, zero, 9
  jalr zero, 0(ra)
rt_greater:
  srai a0, a0, 3
  srai a1, a1, 3
  blt a1, a0, .L_greater_yes
  addi a0, zero, 1
  jalr zero, 0(ra)
.L_greater_yes:
  addi a0, zero, 9
  jalr zero, 0(ra)

rt_box_get:
  andi a0, a0, -8
  lw t0, 0(a0)
  addi a0, a0, 4
.L_box_get_loop:
  beq t0, zero, rt_missing_field
  lw t1, 0(a0)
  beq t1, a1, .L_box_get_found
  addi a0, a0, 8
  addi t0, t0, -1
  j .L_box_get_loop
.L_box_get_found:
  lw a0, 4(a0)
  jalr zero, 0(ra)

rt_box_set:
  andi a0, a0, -8
  lw t0, 0(a0)
  addi a0, a0, 4
.L_box_set_loop:
  beq t0, zero, rt_missing_field
  lw t1, 0(a0)
  beq t1, a1, .L_box_set_found
  addi a0, a0, 8
  addi t0, t0, -1
  j .L_box_set_loop
.L_box_set_found:
  sw a2, 4(a0)
  addi a0, zero, 2
  jalr zero, 0(ra)

rt_group_count:
  andi a0, a0, -8
  lw a0, 0(a0)
  slli a0, a0, 3
  jalr zero, 0(ra)
rt_group_at:
  andi a0, a0, -8
  srai a1, a1, 3
  lw t0, 0(a0)
  bgeu a1, t0, rt_group_bounds
  slli a1, a1, 2
  add a0, a0, a1
  lw a0, 4(a0)
  jalr zero, 0(ra)
rt_group_add:
  addi sp, sp, -16
  sw ra, 12(sp)
  sw a0, 8(sp)
  sw a1, 4(sp)
  andi t0, a0, -8
  lw t1, 0(t0)
  addi a0, t1, 2
  slli a0, a0, 2
  call rt_alloc
  lw t0, 8(sp)
  andi t0, t0, -8
  lw t1, 0(t0)
  addi t2, t1, 1
  sw t2, 0(a0)
  addi t2, zero, 0
.L_group_copy:
  beq t2, t1, .L_group_copy_done
  slli t3, t2, 2
  add t4, t0, t3
  lw t5, 4(t4)
  add t4, a0, t3
  sw t5, 4(t4)
  addi t2, t2, 1
  j .L_group_copy
.L_group_copy_done:
  slli t3, t1, 2
  add t3, a0, t3
  lw t4, 4(sp)
  sw t4, 4(t3)
  ori a0, a0, 4
  lw ra, 12(sp)
  addi sp, sp, 16
  jalr zero, 0(ra)

rt_cstring:
  addi sp, sp, -16
  sw ra, 12(sp)
  sw a0, 8(sp)
  addi t0, a0, 0
  addi t1, zero, 0
.L_cstring_len:
  lbu t2, 0(t0)
  beq t2, zero, .L_cstring_alloc
  addi t0, t0, 1
  addi t1, t1, 1
  j .L_cstring_len
.L_cstring_alloc:
  sw t1, 4(sp)
  addi a0, t1, 5
  call rt_alloc
  lw t1, 4(sp)
  sw t1, 0(a0)
  lw t0, 8(sp)
  addi t2, zero, 0
.L_cstring_copy:
  bgtu t2, t1, .L_cstring_done
  add t3, t0, t2
  lbu t4, 0(t3)
  add t3, a0, t2
  sb t4, 4(t3)
  addi t2, t2, 1
  j .L_cstring_copy
.L_cstring_done:
  ori a0, a0, 3
  lw ra, 12(sp)
  addi sp, sp, 16
  jalr zero, 0(ra)

rt_string_add:
  addi sp, sp, -32
  sw ra, 28(sp)
  andi t0, a0, -8
  andi t1, a1, -8
  sw t0, 24(sp)
  sw t1, 20(sp)
  lw t2, 0(t0)
  lw t3, 0(t1)
  sw t2, 16(sp)
  sw t3, 12(sp)
  add t4, t2, t3
  sw t4, 8(sp)
  addi a0, t4, 5
  call rt_alloc
  lw t4, 8(sp)
  sw t4, 0(a0)
  addi t5, zero, 0
  lw t0, 24(sp)
  lw t1, 20(sp)
  lw t2, 16(sp)
.L_string_left:
  beq t5, t2, .L_string_right_start
  add t3, t0, t5
  lbu t4, 4(t3)
  add t3, a0, t5
  sb t4, 4(t3)
  addi t5, t5, 1
  j .L_string_left
.L_string_right_start:
  addi t6, zero, 0
  lw t2, 12(sp)
.L_string_right:
  beq t6, t2, .L_string_done
  add t3, t1, t6
  lbu t4, 4(t3)
  add t3, a0, t5
  sb t4, 4(t3)
  addi t5, t5, 1
  addi t6, t6, 1
  j .L_string_right
.L_string_done:
  add t3, a0, t5
  sb zero, 4(t3)
  ori a0, a0, 3
  lw ra, 28(sp)
  addi sp, sp, 32
  jalr zero, 0(ra)

rt_string_len:
  andi a0, a0, -8
  lw a0, 0(a0)
  slli a0, a0, 3
  jalr zero, 0(ra)

rt_string_at:
  addi sp, sp, -16
  sw ra, 12(sp)
  andi t0, a0, -8
  srai a1, a1, 3
  lw t1, 0(t0)
  bgeu a1, t1, rt_string_bounds
  add t0, t0, a1
  lbu t1, 4(t0)
  sw t1, 8(sp)
  addi a0, zero, 8
  call rt_alloc
  addi t0, zero, 1
  sw t0, 0(a0)
  lw t1, 8(sp)
  sb t1, 4(a0)
  sb zero, 5(a0)
  ori a0, a0, 3
  lw ra, 12(sp)
  addi sp, sp, 16
  jalr zero, 0(ra)

rt_string_slice:
  addi sp, sp, -32
  sw ra, 28(sp)
  andi t0, a0, -8
  srai a1, a1, 3
  srai a2, a2, 3
  lw t1, 0(t0)
  bgtu a1, a2, rt_string_bounds
  bgtu a2, t1, rt_string_bounds
  sub t2, a2, a1
  sw t0, 24(sp)
  sw a1, 20(sp)
  sw t2, 16(sp)
  addi a0, t2, 5
  call rt_alloc
  lw t0, 24(sp)
  lw t1, 20(sp)
  lw t2, 16(sp)
  sw t2, 0(a0)
  addi t3, zero, 0
.L_slice_copy:
  beq t3, t2, .L_slice_done
  add t4, t1, t3
  add t4, t0, t4
  lbu t5, 4(t4)
  add t4, a0, t3
  sb t5, 4(t4)
  addi t3, t3, 1
  j .L_slice_copy
.L_slice_done:
  add t4, a0, t2
  sb zero, 4(t4)
  ori a0, a0, 3
  lw ra, 28(sp)
  addi sp, sp, 32
  jalr zero, 0(ra)

rt_string_starts_with:
  andi a0, a0, -8
  andi a1, a1, -8
  lw t0, 0(a0)
  lw t1, 0(a1)
  bgtu t1, t0, .L_string_match_no
  addi t2, zero, 0
  j .L_string_match_loop
rt_string_ends_with:
  andi a0, a0, -8
  andi a1, a1, -8
  lw t0, 0(a0)
  lw t1, 0(a1)
  bgtu t1, t0, .L_string_match_no
  sub a0, a0, zero
  sub t3, t0, t1
  add a0, a0, t3
  addi t2, zero, 0
.L_string_match_loop:
  beq t2, t1, .L_string_match_yes
  add t3, a0, t2
  add t4, a1, t2
  lbu t3, 4(t3)
  lbu t4, 4(t4)
  bne t3, t4, .L_string_match_no
  addi t2, t2, 1
  j .L_string_match_loop
.L_string_match_yes:
  addi a0, zero, 9
  jalr zero, 0(ra)
.L_string_match_no:
  addi a0, zero, 1
  jalr zero, 0(ra)

rt_string_contains:
  andi a0, a0, -8
  andi a1, a1, -8
  lw t0, 0(a0)
  lw t1, 0(a1)
  beq t1, zero, .L_contains_yes
  bgtu t1, t0, .L_contains_no
  sub t2, t0, t1
  addi t2, t2, 1
  addi t3, zero, 0
.L_contains_outer:
  beq t3, t2, .L_contains_no
  addi t4, zero, 0
.L_contains_inner:
  beq t4, t1, .L_contains_yes
  add t5, t3, t4
  add t5, a0, t5
  lbu t5, 4(t5)
  add t6, a1, t4
  lbu t6, 4(t6)
  bne t5, t6, .L_contains_next
  addi t4, t4, 1
  j .L_contains_inner
.L_contains_next:
  addi t3, t3, 1
  j .L_contains_outer
.L_contains_yes:
  addi a0, zero, 9
  jalr zero, 0(ra)
.L_contains_no:
  addi a0, zero, 1
  jalr zero, 0(ra)

rt_string_lower:
  addi a1, zero, 0
  j rt_string_case
rt_string_upper:
  addi a1, zero, 1
rt_string_case:
  addi sp, sp, -32
  sw ra, 28(sp)
  andi t0, a0, -8
  lw t1, 0(t0)
  sw t0, 24(sp)
  sw t1, 20(sp)
  sw a1, 16(sp)
  addi a0, t1, 5
  call rt_alloc
  lw t0, 24(sp)
  lw t1, 20(sp)
  lw t2, 16(sp)
  sw t1, 0(a0)
  addi t3, zero, 0
.L_case_loop:
  beq t3, t1, .L_case_done
  add t4, t0, t3
  lbu t5, 4(t4)
  beq t2, zero, .L_case_lower
  addi t4, zero, 97
  bltu t5, t4, .L_case_store
  addi t4, zero, 123
  bgeu t5, t4, .L_case_store
  addi t5, t5, -32
  j .L_case_store
.L_case_lower:
  addi t4, zero, 65
  bltu t5, t4, .L_case_store
  addi t4, zero, 91
  bgeu t5, t4, .L_case_store
  addi t5, t5, 32
.L_case_store:
  add t4, a0, t3
  sb t5, 4(t4)
  addi t3, t3, 1
  j .L_case_loop
.L_case_done:
  add t4, a0, t1
  sb zero, 4(t4)
  ori a0, a0, 3
  lw ra, 28(sp)
  addi sp, sp, 32
  jalr zero, 0(ra)

rt_line_count:
  andi a0, a0, -8
  lw t0, 0(a0)
  beq t0, zero, .L_line_empty
  addi t1, zero, 0
  addi t2, zero, 0
.L_line_loop:
  beq t2, t0, .L_line_done
  add t3, a0, t2
  lbu t4, 4(t3)
  addi t5, zero, 10
  bne t4, t5, .L_line_next
  addi t1, t1, 1
.L_line_next:
  addi t2, t2, 1
  j .L_line_loop
.L_line_done:
  add t3, a0, t0
  lbu t4, 3(t3)
  addi t5, zero, 10
  beq t4, t5, .L_line_encode
  addi t1, t1, 1
.L_line_encode:
  slli a0, t1, 3
  jalr zero, 0(ra)
.L_line_empty:
  addi a0, zero, 0
  jalr zero, 0(ra)

rt_number_text:
  addi sp, sp, -48
  sw ra, 44(sp)
  srai t0, a0, 3
  addi t1, zero, 0
  bge t0, zero, .L_number_abs
  addi t1, zero, 1
  sub t0, zero, t0
.L_number_abs:
  addi t2, sp, 0
  addi t3, zero, 0
  bne t0, zero, .L_number_digits
  addi t4, zero, 48
  sb t4, 0(t2)
  addi t3, zero, 1
  j .L_number_ready
.L_number_digits:
  addi t4, zero, 10
.L_number_digit_loop:
  addi t5, zero, 0
  addi t6, t0, 0
.L_number_div10:
  bltu t6, t4, .L_number_remainder
  addi t6, t6, -10
  addi t5, t5, 1
  j .L_number_div10
.L_number_remainder:
  addi t6, t6, 48
  add t4, t2, t3
  sb t6, 0(t4)
  addi t3, t3, 1
  addi t0, t5, 0
  bne t0, zero, .L_number_digits
.L_number_ready:
  beq t1, zero, .L_number_alloc
  addi t3, t3, 1
.L_number_alloc:
  sw t3, 40(sp)
  addi a0, t3, 5
  call rt_alloc
  lw t3, 40(sp)
  sw t3, 0(a0)
  addi t4, zero, 0
  beq t1, zero, .L_number_copy
  addi t5, zero, 45
  sb t5, 4(a0)
  addi t4, zero, 1
  addi t3, t3, -1
.L_number_copy:
  beq t3, zero, .L_number_done
  addi t3, t3, -1
  add t5, t2, t3
  lbu t6, 0(t5)
  add t5, a0, t4
  sb t6, 4(t5)
  addi t4, t4, 1
  j .L_number_copy
.L_number_done:
  add t5, a0, t4
  sb zero, 4(t5)
  ori a0, a0, 3
  lw ra, 44(sp)
  addi sp, sp, 48
  jalr zero, 0(ra)

rt_show:
  andi t0, a0, 7
  addi t1, zero, 3
  beq t0, t1, .L_show_string
  addi t1, zero, 0
  beq t0, t1, .L_show_number
  la a0, rt_unknown_text
  ori a0, a0, 3
  j .L_show_string
.L_show_number:
  addi sp, sp, -16
  sw ra, 12(sp)
  call rt_number_text
  call rt_show
  lw ra, 12(sp)
  addi sp, sp, 16
  jalr zero, 0(ra)
.L_show_string:
  andi t0, a0, -8
  lw a2, 0(t0)
  addi a1, t0, 4
  addi a0, zero, 1
  addi a7, zero, 64
  ecall
  addi a0, zero, 2
  jalr zero, 0(ra)
rt_newline:
  addi a0, zero, 1
  la a1, rt_newline_text
  addi a2, zero, 1
  addi a7, zero, 64
  ecall
  jalr zero, 0(ra)

rt_file_read:
  addi sp, sp, -32
  sw ra, 28(sp)
  andi t0, a0, -8
  addi a1, t0, 4
  addi a0, zero, -100
  addi a2, zero, 0
  addi a3, zero, 0
  addi a7, zero, 56
  ecall
  blt a0, zero, rt_file_error
  sw a0, 24(sp)
  li a0, 1048584
  call rt_alloc
  sw a0, 20(sp)
  lw a0, 24(sp)
  lw a1, 20(sp)
  addi a1, a1, 4
  li a2, 1048576
  addi a7, zero, 63
  ecall
  blt a0, zero, rt_file_error
  lw t0, 20(sp)
  sw a0, 0(t0)
  add t1, t0, a0
  sb zero, 4(t1)
  lw a0, 24(sp)
  addi a7, zero, 57
  ecall
  lw a0, 20(sp)
  ori a0, a0, 3
  lw ra, 28(sp)
  addi sp, sp, 32
  jalr zero, 0(ra)
rt_file_write:
  addi sp, sp, -32
  sw ra, 28(sp)
  sw a1, 24(sp)
  andi t0, a0, -8
  addi a1, t0, 4
  addi a0, zero, -100
  li a2, 577
  li a3, 420
  addi a7, zero, 56
  ecall
  blt a0, zero, rt_file_error
  sw a0, 20(sp)
  lw t0, 24(sp)
  andi t0, t0, -8
  lw a2, 0(t0)
  addi a1, t0, 4
  lw a0, 20(sp)
  addi a7, zero, 64
  ecall
  lw a0, 20(sp)
  addi a7, zero, 57
  ecall
  addi a0, zero, 2
  lw ra, 28(sp)
  addi sp, sp, 32
  jalr zero, 0(ra)

rt_missing_args:
  addi a0, zero, 64
  addi a7, zero, 93
  ecall
rt_out_of_memory:
  addi a0, zero, 65
  addi a7, zero, 93
  ecall
rt_missing_field:
  li a0, 15
  jalr zero, 0(ra)
rt_group_bounds:
  li a0, 23
  jalr zero, 0(ra)
rt_string_bounds:
  li a0, 47
  jalr zero, 0(ra)
rt_division_by_zero:
  li a0, 31
  jalr zero, 0(ra)
rt_file_error:
  li a0, 39
  lw ra, 28(sp)
  addi sp, sp, 32
  jalr zero, 0(ra)

.section .rodata
.balign 8
rt_unknown_text:
  .word 7
  .ascii \"<value>\"
  .byte 0
  .balign 8
rt_newline_text:
  .byte 10
"
}

skill compiler_finish_data(compiler) {
    compiler = compiler_emit(compiler, ".section .rodata")
    compiler = compiler_emit(compiler, ".balign 8")
    compiler = compiler_emit(compiler, compiler_join_data(compiler.data))
    compiler = compiler_emit(compiler, ".section .bss")
    compiler = compiler_emit(compiler, ".balign 8")
    compiler = compiler_emit(compiler, "saltic_heap:")
    compiler = compiler_emit(compiler, ".space 16777216")
    compiler = compiler_emit(compiler, "saltic_heap_end:")
    out compiler
}

skill compiler_compile(ast) {
    @compiler = CompilerState { ast = ast }
    compiler = compiler_collect_top_level(compiler)
    compiler = compiler_header(compiler)
    compiler = compiler_start(compiler)
    compiler = compiler_compile_functions(compiler)
    compiler = compiler_emit(compiler, compiler_runtime_assembly())
    compiler = compiler_finish_data(compiler)
    out compiler_render_lines(compiler.lines)
}

program() {
    core.io.show("библиотека компилятора")
    out none
}
