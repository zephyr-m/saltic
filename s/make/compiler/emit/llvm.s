use core
use s.run.core.num

LlvmOut = Box {
    text = ""
    diagnostics = []
}

LlvmText = Box {
    text = ""
    length = 0
}

LlvmString = Box {
    found = no
    value = ""
}

LlvmSkillShow = Box {
    found = no
    param = ""
}

LlvmSkillNumeric = Box {
    found = no
}

LlvmSkillDrum = Box {
    found = no
    count = ""
    value = ""
}

LlvmSkillDrumNumber = Box {
    found = no
    name = ""
    initial = "0"
    count = ""
    op = ""
    step = "0"
}

LlvmBoxField = Box {
    found = no
    index = 0
}

LlvmSkillBox = Box {
    found = no
    box = none
}

LlvmSkillBoxChange = Box {
    found = no
    owner = ""
    box = ""
    args = []
}

skill llvm_escape_string(value) {
    @text = ""
    @length = 0
    @index = 0
    @count = core.str.len(value)
    drum (count) {
        (index < count) {
            @ch = core.str.at(value, index)
            @escaped = no
            (ch == "\"") {
                text = core.str.add(text, "\\22")
                escaped = yes
            }
            (ch == "\\") {
                text = core.str.add(text, "\\5C")
                escaped = yes
            }
            (ch == "\n") {
                text = core.str.add(text, "\\0A")
                escaped = yes
            }
            (ch == "\t") {
                text = core.str.add(text, "\\09")
                escaped = yes
            }
            (escaped == no) {
                text = core.str.add(text, ch)
            }
            length = length + 1
            index = index + 1
        }
    }
    out LlvmText {
        text = text
        length = length + 1
    }
}

skill llvm_string_global(name, value) {
    @escaped = llvm_escape_string(value)
    @length_text = core_num_text(escaped.length)
    @text = "@"
    text = core.str.add(text, name)
    text = core.str.add(text, " = private constant [")
    text = core.str.add(text, length_text)
    text = core.str.add(text, " x i8] c\"")
    text = core.str.add(text, escaped.text)
    text = core.str.add(text, "\\00\"\n")
    out text
}

skill llvm_string_pointer(target, name, value) {
    @escaped = llvm_escape_string(value)
    @length_text = core_num_text(escaped.length)
    @text = "  %"
    text = core.str.add(text, target)
    text = core.str.add(text, " = getelementptr [")
    text = core.str.add(text, length_text)
    text = core.str.add(text, " x i8], ptr @")
    text = core.str.add(text, name)
    text = core.str.add(text, ", i32 0, i32 0\n")
    out text
}

skill llvm_group_init(name, group) {
    @text = "  %"
    text = core.str.add(text, name)
    text = core.str.add(text, " = alloca %Group\n  %")
    text = core.str.add(text, name)
    text = core.str.add(text, "_count = getelementptr %Group, ptr %")
    text = core.str.add(text, name)
    text = core.str.add(text, ", i32 0, i32 0\n  store i32 ")
    text = core.str.add(text, core_num_text(core.group.count(group.args)))
    text = core.str.add(text, ", ptr %")
    text = core.str.add(text, name)
    text = core.str.add(text, "_count\n")

    @index = 0
    @count = core.group.count(group.args)
    drum (count) {
        (index < count) {
            @item = core.group.item(group.args, index)
            @index_text = core_num_text(index)
            text = core.str.add(text, "  %")
            text = core.str.add(text, name)
            text = core.str.add(text, "_item_")
            text = core.str.add(text, index_text)
            text = core.str.add(text, " = getelementptr %Group, ptr %")
            text = core.str.add(text, name)
            text = core.str.add(text, ", i32 0, i32 1, i32 ")
            text = core.str.add(text, index_text)
            text = core.str.add(text, "\n  store i32 ")
            text = core.str.add(text, item.value)
            text = core.str.add(text, ", ptr %")
            text = core.str.add(text, name)
            text = core.str.add(text, "_item_")
            text = core.str.add(text, index_text)
            text = core.str.add(text, "\n")
            index = index + 1
        }
    }
    out text
}

skill llvm_group_runtime() {
    out "define void @group_add(ptr %source, i32 %value, ptr %target) {\nentry:\n  %source_count_ptr = getelementptr %Group, ptr %source, i32 0, i32 0\n  %source_count = load i32, ptr %source_count_ptr\n  %has_space = icmp slt i32 %source_count, 16\n  %next_count = add i32 %source_count, 1\n  %target_count = select i1 %has_space, i32 %next_count, i32 %source_count\n  %target_count_ptr = getelementptr %Group, ptr %target, i32 0, i32 0\n  store i32 %target_count, ptr %target_count_ptr\n  br label %copy_test\ncopy_test:\n  %copy_index = phi i32 [ 0, %entry ], [ %copy_next, %copy_body ]\n  %copy_more = icmp slt i32 %copy_index, %source_count\n  br i1 %copy_more, label %copy_body, label %append_test\ncopy_body:\n  %source_item_ptr = getelementptr %Group, ptr %source, i32 0, i32 1, i32 %copy_index\n  %source_item = load i32, ptr %source_item_ptr\n  %target_item_ptr = getelementptr %Group, ptr %target, i32 0, i32 1, i32 %copy_index\n  store i32 %source_item, ptr %target_item_ptr\n  %copy_next = add i32 %copy_index, 1\n  br label %copy_test\nappend_test:\n  br i1 %has_space, label %append, label %done\nappend:\n  %append_ptr = getelementptr %Group, ptr %target, i32 0, i32 1, i32 %source_count\n  store i32 %value, ptr %append_ptr\n  br label %done\ndone:\n  ret void\n}\n"
}

skill llvm_group_add(name, call) {
    @source = core.group.item(call.args, 0)
    @value = core.group.item(call.args, 1)
    @text = "  %"
    text = core.str.add(text, name)
    text = core.str.add(text, " = alloca %Group\n  call void @group_add(ptr %")
    text = core.str.add(text, source.value)
    text = core.str.add(text, ", i32 ")
    text = core.str.add(text, value.value)
    text = core.str.add(text, ", ptr %")
    text = core.str.add(text, name)
    text = core.str.add(text, ")\n")
    out text
}

skill llvm_box_types(instructions) {
    @text = ""
    @index = 0
    @count = core.group.count(instructions)
    drum (count) {
        (index < count) {
            @instruction = core.group.item(instructions, index)
            (instruction.op == "BOX_DECL") {
                text = core.str.add(text, "%Box_")
                text = core.str.add(text, instruction.name)
                text = core.str.add(text, " = type { ")
                @field_index = 0
                @field_count = core.group.count(instruction.body)
                drum (field_count) {
                    (field_index < field_count) {
                        (field_index > 0) {
                            text = core.str.add(text, ", ")
                        }
                        text = core.str.add(text, "i32")
                        field_index = field_index + 1
                    }
                }
                text = core.str.add(text, " }\n")
            }
            index = index + 1
        }
    }
    out text
}

skill llvm_box_init(instructions, name, box) {
    @text = "  %"
    text = core.str.add(text, name)
    text = core.str.add(text, " = alloca %Box_")
    text = core.str.add(text, box.name)
    text = core.str.add(text, "\n")
    @declaration = core.group.item(instructions, 0)
    @decl_index = 0
    @decl_count = core.group.count(instructions)
    drum (decl_count) {
        (decl_index < decl_count) {
            @candidate = core.group.item(instructions, decl_index)
            (candidate.op == "BOX_DECL") {
                (candidate.name == box.name) {
                    declaration = candidate
                }
            }
            decl_index = decl_index + 1
        }
    }

    @index = 0
    @count = core.group.count(declaration.body)
    drum (count) {
        (index < count) {
            @field = core.group.item(declaration.body, index)
            @field_value = field.value
            @override_index = 0
            @override_count = core.group.count(box.body)
            drum (override_count) {
                (override_index < override_count) {
                    @override = core.group.item(box.body, override_index)
                    (override.name == field.name) {
                        field_value = override.value
                    }
                    override_index = override_index + 1
                }
            }
            @index_text = core_num_text(index)
            text = core.str.add(text, "  %")
            text = core.str.add(text, name)
            text = core.str.add(text, "_field_")
            text = core.str.add(text, index_text)
            text = core.str.add(text, " = getelementptr %Box_")
            text = core.str.add(text, box.name)
            text = core.str.add(text, ", ptr %")
            text = core.str.add(text, name)
            text = core.str.add(text, ", i32 0, i32 ")
            text = core.str.add(text, index_text)
            text = core.str.add(text, "\n  store i32 ")
            text = core.str.add(text, field_value.value)
            text = core.str.add(text, ", ptr %")
            text = core.str.add(text, name)
            text = core.str.add(text, "_field_")
            text = core.str.add(text, index_text)
            text = core.str.add(text, "\n")
            index = index + 1
        }
    }
    out text
}

skill llvm_box_field(instructions, box_name, field_name) {
    @found = no
    @result = 0
    @index = 0
    @count = core.group.count(instructions)
    drum (count) {
        (index < count) {
            @instruction = core.group.item(instructions, index)
            (instruction.op == "BOX_DECL") {
                (instruction.name == box_name) {
                    @field_index = 0
                    @field_count = core.group.count(instruction.body)
                    drum (field_count) {
                        (field_index < field_count) {
                            @field = core.group.item(instruction.body, field_index)
                            (field.name == field_name) {
                                found = yes
                                result = field_index
                            }
                            field_index = field_index + 1
                        }
                    }
                }
            }
            index = index + 1
        }
    }
    out LlvmBoxField {
        found = found
        index = result
    }
}

skill llvm_skill_box(instruction) {
    @found = no
    @box = none
    @index = 0
    @count = core.group.count(instruction.body)
    drum (count) {
        (index < count) {
            @body_instruction = core.group.item(instruction.body, index)
            (body_instruction.op == "OUT") {
                (body_instruction.value.op == "BOX") {
                    found = yes
                    box = body_instruction.value
                }
            }
            index = index + 1
        }
    }
    out LlvmSkillBox {
        found = found
        box = box
    }
}

skill llvm_box_operand(value) {
    (value.op == "PATH") {
        out core.str.add("%", value.value)
    }
    out value.value
}

skill llvm_skill_box_function(instructions, instruction, box) {
    @text = "define void @"
    text = core.str.add(text, instruction.name)
    text = core.str.add(text, "(")
    @arg_index = 0
    @arg_count = core.group.count(instruction.args)
    drum (arg_count) {
        (arg_index < arg_count) {
            (arg_index > 0) { text = core.str.add(text, ", ") }
            text = core.str.add(text, "i32 %")
            text = core.str.add(text, core.group.item(instruction.args, arg_index))
            arg_index = arg_index + 1
        }
    }
    (arg_count > 0) { text = core.str.add(text, ", ") }
    text = core.str.add(text, "ptr %result) {\nentry:\n")

    @declaration = core.group.item(instructions, 0)
    @decl_index = 0
    @decl_count = core.group.count(instructions)
    drum (decl_count) {
        (decl_index < decl_count) {
            @candidate = core.group.item(instructions, decl_index)
            (candidate.op == "BOX_DECL") {
                (candidate.name == box.name) { declaration = candidate }
            }
            decl_index = decl_index + 1
        }
    }
    @field_index = 0
    @field_count = core.group.count(declaration.body)
    drum (field_count) {
        (field_index < field_count) {
            @field = core.group.item(declaration.body, field_index)
            @field_value = field.value
            @override_index = 0
            @override_count = core.group.count(box.body)
            drum (override_count) {
                (override_index < override_count) {
                    @override = core.group.item(box.body, override_index)
                    (override.name == field.name) { field_value = override.value }
                    override_index = override_index + 1
                }
            }
            @field_id = core_num_text(field_index)
            text = core.str.add(text, "  %result_field_")
            text = core.str.add(text, field_id)
            text = core.str.add(text, " = getelementptr %Box_")
            text = core.str.add(text, box.name)
            text = core.str.add(text, ", ptr %result, i32 0, i32 ")
            text = core.str.add(text, field_id)
            text = core.str.add(text, "\n  store i32 ")
            text = core.str.add(text, llvm_box_operand(field_value))
            text = core.str.add(text, ", ptr %result_field_")
            text = core.str.add(text, field_id)
            text = core.str.add(text, "\n")
            field_index = field_index + 1
        }
    }
    text = core.str.add(text, "  ret void\n}\n")
    out text
}

skill llvm_find_skill_box(instructions, name) {
    @found = no
    @box = none
    @index = 0
    @count = core.group.count(instructions)
    drum (count) {
        (index < count) {
            @instruction = core.group.item(instructions, index)
            (instruction.op == "SKILL") {
                (instruction.name == name) {
                    @result = llvm_skill_box(instruction)
                    (result.found == yes) {
                        found = yes
                        box = result.box
                    }
                }
            }
            index = index + 1
        }
    }
    out LlvmSkillBox { found = found, box = box }
}

skill llvm_box_for_field(instructions, field_name) {
    @box_name = ""
    @index = 0
    @count = core.group.count(instructions)
    drum (count) {
        (index < count) {
            @instruction = core.group.item(instructions, index)
            (instruction.op == "BOX_DECL") {
                @field = llvm_box_field(instructions, instruction.name, field_name)
                (field.found == yes) { box_name = instruction.name }
            }
            index = index + 1
        }
    }
    out box_name
}

skill llvm_skill_box_change(instructions, instruction) {
    @found = no
    @owner = ""
    @box = ""
    @field_name = ""
    @index = 0
    @count = core.group.count(instruction.body)
    drum (count) {
        (index < count) {
            @body_instruction = core.group.item(instruction.body, index)
            (body_instruction.op == "FIELD_SET") {
                @field_owner = core.group.item(body_instruction.args, 0)
                owner = field_owner.value
                field_name = body_instruction.name
            }
            index = index + 1
        }
    }
    (owner == "") { out LlvmSkillBoxChange { found = no, owner = "", box = "", args = instruction.args } }
    @out_index = 0
    drum (count) {
        (out_index < count) {
            @body_instruction = core.group.item(instruction.body, out_index)
            (body_instruction.op == "OUT") {
                (body_instruction.value.op == "PATH") {
                    (body_instruction.value.value == owner) { found = yes }
                }
            }
            out_index = out_index + 1
        }
    }
    box = llvm_box_for_field(instructions, field_name)
    (box == "") { found = no }
    out LlvmSkillBoxChange { found = found, owner = owner, box = box, args = instruction.args }
}

skill llvm_skill_box_change_function(instructions, instruction, change) {
    @text = "define ptr @"
    text = core.str.add(text, instruction.name)
    text = core.str.add(text, "(")
    @arg_index = 0
    @arg_count = core.group.count(instruction.args)
    drum (arg_count) {
        (arg_index < arg_count) {
            (arg_index > 0) { text = core.str.add(text, ", ") }
            @arg_name = core.group.item(instruction.args, arg_index)
            @is_owner = no
            (arg_name == change.owner) {
                text = core.str.add(text, "ptr %")
                is_owner = yes
            }
            (is_owner == no) { text = core.str.add(text, "i32 %") }
            text = core.str.add(text, arg_name)
            arg_index = arg_index + 1
        }
    }
    text = core.str.add(text, ") {\nentry:\n")
    @body_index = 0
    @body_count = core.group.count(instruction.body)
    drum (body_count) {
        (body_index < body_count) {
            @body_instruction = core.group.item(instruction.body, body_index)
            (body_instruction.op == "FIELD_SET") {
                @field = llvm_box_field(instructions, change.box, body_instruction.name)
                @field_id = core_num_text(field.index)
                @set_id = core_num_text(body_index)
                text = core.str.add(text, "  %field_ptr_")
                text = core.str.add(text, set_id)
                text = core.str.add(text, " = getelementptr %Box_")
                text = core.str.add(text, change.box)
                text = core.str.add(text, ", ptr %")
                text = core.str.add(text, change.owner)
                text = core.str.add(text, ", i32 0, i32 ")
                text = core.str.add(text, field_id)
                text = core.str.add(text, "\n  store i32 ")
                text = core.str.add(text, llvm_box_operand(body_instruction.value))
                text = core.str.add(text, ", ptr %field_ptr_")
                text = core.str.add(text, set_id)
                text = core.str.add(text, "\n")
            }
            body_index = body_index + 1
        }
    }
    text = core.str.add(text, "  ret ptr %")
    text = core.str.add(text, change.owner)
    text = core.str.add(text, "\n}\n")
    out text
}

skill llvm_box_change_call(name, call, change) {
    @text = "  %"
    text = core.str.add(text, name)
    text = core.str.add(text, " = call ptr @")
    text = core.str.add(text, call.name)
    text = core.str.add(text, "(")
    @index = 0
    @count = core.group.count(call.args)
    drum (count) {
        (index < count) {
            (index > 0) { text = core.str.add(text, ", ") }
            @argument = core.group.item(call.args, index)
            @parameter = core.group.item(change.args, index)
            @is_owner = no
            (parameter == change.owner) {
                text = core.str.add(text, "ptr %")
                is_owner = yes
            }
            (is_owner == no) { text = core.str.add(text, "i32 ") }
            text = core.str.add(text, argument.value)
            index = index + 1
        }
    }
    text = core.str.add(text, ")\n")
    out text
}

skill llvm_find_skill_box_change(instructions, name) {
    @result = LlvmSkillBoxChange { found = no, owner = "", box = "", args = [] }
    @index = 0
    @count = core.group.count(instructions)
    drum (count) {
        (index < count) {
            @instruction = core.group.item(instructions, index)
            (instruction.op == "SKILL") {
                (instruction.name == name) { result = llvm_skill_box_change(instructions, instruction) }
            }
            index = index + 1
        }
    }
    out result
}

skill llvm_box_call(name, call, box_name) {
    @text = "  %"
    text = core.str.add(text, name)
    text = core.str.add(text, " = alloca %Box_")
    text = core.str.add(text, box_name)
    text = core.str.add(text, "\n  call void @")
    text = core.str.add(text, call.name)
    text = core.str.add(text, "(")
    @index = 0
    @count = core.group.count(call.args)
    drum (count) {
        (index < count) {
            (index > 0) { text = core.str.add(text, ", ") }
            text = core.str.add(text, "i32 ")
            text = core.str.add(text, llvm_box_operand(core.group.item(call.args, index)))
            index = index + 1
        }
    }
    (count > 0) { text = core.str.add(text, ", ") }
    text = core.str.add(text, "ptr %")
    text = core.str.add(text, name)
    text = core.str.add(text, ")\n")
    out text
}

skill llvm_skill_string(instructions, name) {
    @found = no
    @result = ""
    @index = 0
    @count = core.group.count(instructions)
    drum (count) {
        (index < count) {
            @instruction = core.group.item(instructions, index)
            (instruction.op == "SKILL") {
                (instruction.name == name) {
                    @body_index = 0
                    @body_count = core.group.count(instruction.body)
                    drum (body_count) {
                        (body_index < body_count) {
                            @body_instruction = core.group.item(instruction.body, body_index)
                            (body_instruction.op == "OUT") {
                                (body_instruction.value.op == "STRING") {
                                    result = body_instruction.value.value
                                    found = yes
                                }
                            }
                            body_index = body_index + 1
                        }
                    }
                }
            }
            index = index + 1
        }
    }
    out LlvmString {
        found = found
        value = result
    }
}

skill llvm_skill_function(name, value) {
    @global_name = core.str.add("skill_", name)
    @text = llvm_string_global(global_name, value)
    text = core.str.add(text, "define ptr @")
    text = core.str.add(text, name)
    text = core.str.add(text, "() {\nentry:\n")
    text = core.str.add(text, llvm_string_pointer("value", global_name, value))
    text = core.str.add(text, "  ret ptr %value\n}\n")
    out text
}

skill llvm_skill_show(instruction) {
    @found = no
    @param = ""
    @arg_count = core.group.count(instruction.args)
    (arg_count == 1) {
        param = core.group.item(instruction.args, 0)
        @body_index = 0
        @body_count = core.group.count(instruction.body)
        drum (body_count) {
            (body_index < body_count) {
                @body_instruction = core.group.item(instruction.body, body_index)
                (body_instruction.op == "WRITE") {
                    @write_arg = core.group.item(body_instruction.args, 0)
                    (write_arg.op == "PATH") {
                        (write_arg.value == param) {
                            found = yes
                        }
                    }
                }
                body_index = body_index + 1
            }
        }
    }
    out LlvmSkillShow {
        found = found
        param = param
    }
}

skill llvm_skill_show_function(name, param) {
    @text = "define i32 @"
    text = core.str.add(text, name)
    text = core.str.add(text, "(ptr %")
    text = core.str.add(text, param)
    text = core.str.add(text, ") {\nentry:\n  call i32 @puts(ptr %")
    text = core.str.add(text, param)
    text = core.str.add(text, ")\n  ret i32 0\n}\n")
    out text
}

skill llvm_math_op(name) {
    (name == "core.num.add") { out "add" }
    (name == "core.num.sub") { out "sub" }
    (name == "core.num.mul") { out "mul" }
    (name == "core.num.div") { out "sdiv" }
    out ""
}

skill llvm_compare_op(name) {
    (name == "core.num.gt") { out "sgt" }
    (name == "core.num.lt") { out "slt" }
    (name == "core.num.eq") { out "eq" }
    out ""
}

skill llvm_skill_numeric(instruction) {
    @found = no
    @index = 0
    @count = core.group.count(instruction.body)
    drum (count) {
        (index < count) {
            @body_instruction = core.group.item(instruction.body, index)
            (body_instruction.op == "ASSIGN") {
                (body_instruction.value.op == "CALL") {
                    @op = llvm_math_op(body_instruction.value.name)
                    (op == "add") { found = yes }
                    (op == "sub") { found = yes }
                    (op == "mul") { found = yes }
                    (op == "sdiv") { found = yes }
                }
            }
            (body_instruction.op == "OUT") {
                (body_instruction.value.op == "CALL") {
                    @op = llvm_math_op(body_instruction.value.name)
                    (op == "add") { found = yes }
                    (op == "sub") { found = yes }
                    (op == "mul") { found = yes }
                    (op == "sdiv") { found = yes }
                }
            }
            (body_instruction.op == "IF") {
                (body_instruction.value.op == "CALL") {
                    @compare = llvm_compare_op(body_instruction.value.name)
                    (compare == "sgt") { found = yes }
                    (compare == "slt") { found = yes }
                    (compare == "eq") { found = yes }
                }
            }
            index = index + 1
        }
    }
    out LlvmSkillNumeric {
        found = found
    }
}

skill llvm_numeric_operand(value) {
    (value.op == "PATH") {
        out core.str.add("%", value.value)
    }
    out value.value
}

skill llvm_numeric_call(target, call) {
    @left = core.group.item(call.args, 0)
    @right = core.group.item(call.args, 1)
    @text = "  %"
    text = core.str.add(text, target)
    text = core.str.add(text, " = ")
    text = core.str.add(text, llvm_math_op(call.name))
    text = core.str.add(text, " i32 ")
    text = core.str.add(text, llvm_numeric_operand(left))
    text = core.str.add(text, ", ")
    text = core.str.add(text, llvm_numeric_operand(right))
    text = core.str.add(text, "\n")
    out text
}

skill llvm_skill_numeric_function(instruction) {
    @text = "define i32 @"
    text = core.str.add(text, instruction.name)
    text = core.str.add(text, "(")

    @arg_index = 0
    @arg_count = core.group.count(instruction.args)
    drum (arg_count) {
        (arg_index < arg_count) {
            (arg_index > 0) {
                text = core.str.add(text, ", ")
            }
            text = core.str.add(text, "i32 %")
            text = core.str.add(text, core.group.item(instruction.args, arg_index))
            arg_index = arg_index + 1
        }
    }
    text = core.str.add(text, ") {\nentry:\n")

    @body_index = 0
    @body_count = core.group.count(instruction.body)
    drum (body_count) {
        (body_index < body_count) {
            @body_instruction = core.group.item(instruction.body, body_index)
            (body_instruction.op == "ASSIGN") {
                (body_instruction.value.op == "CALL") {
                    text = core.str.add(text, llvm_numeric_call(body_instruction.name, body_instruction.value))
                }
            }
            (body_instruction.op == "OUT") {
                (body_instruction.value.op == "CALL") {
                    @result_name = core.str.add("result_", core_num_text(body_index))
                    text = core.str.add(text, llvm_numeric_call(result_name, body_instruction.value))
                    text = core.str.add(text, "  ret i32 %")
                    text = core.str.add(text, result_name)
                    text = core.str.add(text, "\n")
                }
                (body_instruction.value.op == "PATH") {
                    text = core.str.add(text, "  ret i32 %")
                    text = core.str.add(text, body_instruction.value.value)
                    text = core.str.add(text, "\n")
                }
                (body_instruction.value.op == "NUMBER") {
                    text = core.str.add(text, "  ret i32 ")
                    text = core.str.add(text, body_instruction.value.value)
                    text = core.str.add(text, "\n")
                }
            }
            (body_instruction.op == "IF") {
                @test = body_instruction.value
                (test.op == "CALL") {
                    @compare = llvm_compare_op(test.name)
                    @left = core.group.item(test.args, 0)
                    @right = core.group.item(test.args, 1)
                    @if_id = core_num_text(body_index)
                    @test_name = core.str.add("test_", if_id)
                    @if_label = core.str.add("if_", if_id)
                    @next_label = core.str.add("next_", if_id)
                    text = core.str.add(text, "  %")
                    text = core.str.add(text, test_name)
                    text = core.str.add(text, " = icmp ")
                    text = core.str.add(text, compare)
                    text = core.str.add(text, " i32 ")
                    text = core.str.add(text, llvm_numeric_operand(left))
                    text = core.str.add(text, ", ")
                    text = core.str.add(text, llvm_numeric_operand(right))
                    text = core.str.add(text, "\n  br i1 %")
                    text = core.str.add(text, test_name)
                    text = core.str.add(text, ", label %")
                    text = core.str.add(text, if_label)
                    text = core.str.add(text, ", label %")
                    text = core.str.add(text, next_label)
                    text = core.str.add(text, "\n")
                    text = core.str.add(text, if_label)
                    text = core.str.add(text, ":\n")

                    @if_body_index = 0
                    @if_body_count = core.group.count(body_instruction.body)
                    drum (if_body_count) {
                        (if_body_index < if_body_count) {
                            @if_instruction = core.group.item(body_instruction.body, if_body_index)
                            (if_instruction.op == "OUT") {
                                text = core.str.add(text, "  ret i32 ")
                                text = core.str.add(text, llvm_numeric_operand(if_instruction.value))
                                text = core.str.add(text, "\n")
                            }
                            if_body_index = if_body_index + 1
                        }
                    }
                    text = core.str.add(text, next_label)
                    text = core.str.add(text, ":\n")
                }
            }
            body_index = body_index + 1
        }
    }
    text = core.str.add(text, "}\n")
    out text
}

skill llvm_skill_drum(instruction) {
    @found = no
    @count_name = ""
    @value = ""
    @index = 0
    @count = core.group.count(instruction.body)
    drum (count) {
        (index < count) {
            @body_instruction = core.group.item(instruction.body, index)
            (body_instruction.op == "DRUM") {
                count_name = body_instruction.value.value
                @drum_index = 0
                @drum_count = core.group.count(body_instruction.body)
                drum (drum_count) {
                    (drum_index < drum_count) {
                        @drum_instruction = core.group.item(body_instruction.body, drum_index)
                        (drum_instruction.op == "WRITE") {
                            @write_value = core.group.item(drum_instruction.args, 0)
                            (write_value.op == "STRING") {
                                value = write_value.value
                                found = yes
                            }
                        }
                        drum_index = drum_index + 1
                    }
                }
            }
            index = index + 1
        }
    }
    out LlvmSkillDrum {
        found = found
        count = count_name
        value = value
    }
}

skill llvm_skill_drum_function(instruction, loop) {
    @global_name = core.str.add("drum_", instruction.name)
    @pointer_name = core.str.add("drum_ptr_", instruction.name)
    @text = llvm_string_global(global_name, loop.value)
    text = core.str.add(text, "define i32 @")
    text = core.str.add(text, instruction.name)
    text = core.str.add(text, "(i32 %")
    text = core.str.add(text, loop.count)
    text = core.str.add(text, ") {\nentry:\n")
    text = core.str.add(text, llvm_string_pointer(pointer_name, global_name, loop.value))
    text = core.str.add(text, "  br label %drum_test\ndrum_test:\n  %drum_index = phi i32 [ 0, %entry ], [ %drum_next, %drum_body ]\n  %drum_more = icmp slt i32 %drum_index, %")
    text = core.str.add(text, loop.count)
    text = core.str.add(text, "\n  br i1 %drum_more, label %drum_body, label %drum_done\ndrum_body:\n  call i32 @puts(ptr %")
    text = core.str.add(text, pointer_name)
    text = core.str.add(text, ")\n  %drum_next = add i32 %drum_index, 1\n  br label %drum_test\ndrum_done:\n  ret i32 0\n}\n")
    out text
}

skill llvm_skill_drum_number(instruction) {
    @found = no
    @name = ""
    @initial = "0"
    @count_name = ""
    @op = ""
    @step = "0"
    @returns_name = ""
    @index = 0
    @count = core.group.count(instruction.body)
    drum (count) {
        (index < count) {
            @body_instruction = core.group.item(instruction.body, index)
            (body_instruction.op == "ASSIGN") {
                (body_instruction.value.op == "NUMBER") {
                    name = body_instruction.name
                    initial = body_instruction.value.value
                }
            }
            (body_instruction.op == "DRUM") {
                count_name = body_instruction.value.value
                @drum_index = 0
                @drum_count = core.group.count(body_instruction.body)
                drum (drum_count) {
                    (drum_index < drum_count) {
                        @drum_instruction = core.group.item(body_instruction.body, drum_index)
                        (drum_instruction.op == "ASSIGN") {
                            (drum_instruction.name == name) {
                                (drum_instruction.value.op == "CALL") {
                                    op = llvm_math_op(drum_instruction.value.name)
                                    @left = core.group.item(drum_instruction.value.args, 0)
                                    @right = core.group.item(drum_instruction.value.args, 1)
                                    (left.value == name) {
                                        step = right.value
                                    }
                                }
                            }
                        }
                        drum_index = drum_index + 1
                    }
                }
            }
            (body_instruction.op == "OUT") {
                (body_instruction.value.op == "PATH") {
                    returns_name = body_instruction.value.value
                }
            }
            index = index + 1
        }
    }
    (returns_name == name) {
        (op == "add") { found = yes }
        (op == "sub") { found = yes }
        (op == "mul") { found = yes }
        (op == "sdiv") { found = yes }
    }
    out LlvmSkillDrumNumber {
        found = found
        name = name
        initial = initial
        count = count_name
        op = op
        step = step
    }
}

skill llvm_skill_drum_number_function(instruction, loop) {
    @text = "define i32 @"
    text = core.str.add(text, instruction.name)
    text = core.str.add(text, "(i32 %")
    text = core.str.add(text, loop.count)
    text = core.str.add(text, ") {\nentry:\n  br label %drum_test\ndrum_test:\n  %drum_index = phi i32 [ 0, %entry ], [ %drum_next, %drum_body ]\n  %")
    text = core.str.add(text, loop.name)
    text = core.str.add(text, " = phi i32 [ ")
    text = core.str.add(text, loop.initial)
    text = core.str.add(text, ", %entry ], [ %")
    text = core.str.add(text, loop.name)
    text = core.str.add(text, "_next, %drum_body ]\n  %drum_more = icmp slt i32 %drum_index, %")
    text = core.str.add(text, loop.count)
    text = core.str.add(text, "\n  br i1 %drum_more, label %drum_body, label %drum_done\ndrum_body:\n  %")
    text = core.str.add(text, loop.name)
    text = core.str.add(text, "_next = ")
    text = core.str.add(text, loop.op)
    text = core.str.add(text, " i32 %")
    text = core.str.add(text, loop.name)
    text = core.str.add(text, ", ")
    text = core.str.add(text, loop.step)
    text = core.str.add(text, "\n  %drum_next = add i32 %drum_index, 1\n  br label %drum_test\ndrum_done:\n  ret i32 %")
    text = core.str.add(text, loop.name)
    text = core.str.add(text, "\n}\n")
    out text
}

skill llvm_resolve(value, names, values) {
    @resolved = value
    (value.op == "PATH") {
        @index = 0
        @count = core.group.count(names)
        drum (count) {
            (index < count) {
                (core.group.item(names, index) == value.value) {
                    resolved = core.group.item(values, index)
                }
                index = index + 1
            }
        }
    }
    out resolved
}

skill llvm_emit(instructions) {
    @globals = ""
    @declarations = "%Group = type { i32, [16 x i32] }\n"
    declarations = core.str.add(declarations, llvm_box_types(instructions))
    declarations = core.str.add(declarations, "declare i32 @printf(ptr, ...)\ndeclare i32 @puts(ptr)\ndeclare i32 @system(ptr)\n")
    @functions = llvm_group_runtime()
    @main = ""
    @exit_value = "0"
    @names = []
    @values = []
    @box_names = []
    @box_types = []
    @fmt_added = no

    @skill_index = 0
    @skill_count = core.group.count(instructions)
    drum (skill_count) {
        (skill_index < skill_count) {
            @skill_instruction = core.group.item(instructions, skill_index)
            (skill_instruction.op == "SKILL") {
                @skill_value = llvm_skill_string(instructions, skill_instruction.name)
                (skill_value.found == yes) {
                    functions = core.str.add(functions, llvm_skill_function(skill_instruction.name, skill_value.value))
                }
                @skill_show = llvm_skill_show(skill_instruction)
                (skill_show.found == yes) {
                    functions = core.str.add(functions, llvm_skill_show_function(skill_instruction.name, skill_show.param))
                }
                @skill_numeric = llvm_skill_numeric(skill_instruction)
                (skill_numeric.found == yes) {
                    functions = core.str.add(functions, llvm_skill_numeric_function(skill_instruction))
                }
                @skill_drum = llvm_skill_drum(skill_instruction)
                (skill_drum.found == yes) {
                    functions = core.str.add(functions, llvm_skill_drum_function(skill_instruction, skill_drum))
                }
                @skill_drum_number = llvm_skill_drum_number(skill_instruction)
                (skill_drum_number.found == yes) {
                    functions = core.str.add(functions, llvm_skill_drum_number_function(skill_instruction, skill_drum_number))
                }
                @skill_box = llvm_skill_box(skill_instruction)
                (skill_box.found == yes) {
                    functions = core.str.add(functions, llvm_skill_box_function(instructions, skill_instruction, skill_box.box))
                }
                @skill_box_change = llvm_skill_box_change(instructions, skill_instruction)
                (skill_box_change.found == yes) {
                    functions = core.str.add(functions, llvm_skill_box_change_function(instructions, skill_instruction, skill_box_change))
                }
            }
            skill_index = skill_index + 1
        }
    }

    @index = 0
    @count = core.group.count(instructions)
    drum (count) {
        (index < count) {
            @instruction = core.group.item(instructions, index)
            @id = core_num_text(index)

            (instruction.op == "ASSIGN") {
                names = core.group.add(names, instruction.name)
                values = core.group.add(values, instruction.value)
                (instruction.value.op == "GROUP") {
                    main = core.str.add(main, llvm_group_init(instruction.name, instruction.value))
                }
                (instruction.value.op == "BOX") {
                    main = core.str.add(main, llvm_box_init(instructions, instruction.name, instruction.value))
                    box_names = core.group.add(box_names, instruction.name)
                    box_types = core.group.add(box_types, instruction.value.name)
                }
                (instruction.value.op == "CALL") {
                    (instruction.value.name == "core.group.add") {
                        main = core.str.add(main, llvm_group_add(instruction.name, instruction.value))
                    }
                    @call_box = llvm_find_skill_box(instructions, instruction.value.name)
                    (call_box.found == yes) {
                        main = core.str.add(main, llvm_box_call(instruction.name, instruction.value, call_box.box.name))
                        box_names = core.group.add(box_names, instruction.name)
                        box_types = core.group.add(box_types, call_box.box.name)
                    }
                    @call_change = llvm_find_skill_box_change(instructions, instruction.value.name)
                    (call_change.found == yes) {
                        main = core.str.add(main, llvm_box_change_call(instruction.name, instruction.value, call_change))
                        box_names = core.group.add(box_names, instruction.name)
                        box_types = core.group.add(box_types, call_change.box)
                    }
                }
            }

            (instruction.op == "FIELD_SET") {
                @owner = core.group.item(instruction.args, 0)
                @box_name = ""
                @box_index = 0
                @box_count = core.group.count(box_names)
                drum (box_count) {
                    (box_index < box_count) {
                        (core.group.item(box_names, box_index) == owner.value) { box_name = core.group.item(box_types, box_index) }
                        box_index = box_index + 1
                    }
                }
                @field = llvm_box_field(instructions, box_name, instruction.name)
                (field.found == yes) {
                    @field_id = core_num_text(field.index)
                    @field_ptr = core.str.add("box_set_ptr_", id)
                    main = core.str.add(main, "  %")
                    main = core.str.add(main, field_ptr)
                    main = core.str.add(main, " = getelementptr %Box_")
                    main = core.str.add(main, box_name)
                    main = core.str.add(main, ", ptr %")
                    main = core.str.add(main, owner.value)
                    main = core.str.add(main, ", i32 0, i32 ")
                    main = core.str.add(main, field_id)
                    main = core.str.add(main, "\n  store i32 ")
                    main = core.str.add(main, instruction.value.value)
                    main = core.str.add(main, ", ptr %")
                    main = core.str.add(main, field_ptr)
                    main = core.str.add(main, "\n")
                }
            }

            (instruction.op == "OUT") {
                @out_value = llvm_resolve(instruction.value, names, values)
                (out_value.op == "NUMBER") {
                    exit_value = out_value.value
                }
                (out_value.op == "CALL") {
                    @out_arg_count = core.group.count(out_value.args)
                    (out_value.name == "core.group.count") {
                        @group_arg = core.group.item(out_value.args, 0)
                        @group_count_ptr = core.str.add("group_count_ptr_", id)
                        @group_count_value = core.str.add("group_count_", id)
                        main = core.str.add(main, "  %")
                        main = core.str.add(main, group_count_ptr)
                        main = core.str.add(main, " = getelementptr %Group, ptr %")
                        main = core.str.add(main, group_arg.value)
                        main = core.str.add(main, ", i32 0, i32 0\n  %")
                        main = core.str.add(main, group_count_value)
                        main = core.str.add(main, " = load i32, ptr %")
                        main = core.str.add(main, group_count_ptr)
                        main = core.str.add(main, "\n")
                        exit_value = core.str.add("%", group_count_value)
                    }
                    (out_value.name == "core.group.item") {
                        @group_arg = core.group.item(out_value.args, 0)
                        @index_arg = core.group.item(out_value.args, 1)
                        @group_item_ptr = core.str.add("group_item_ptr_", id)
                        @group_item_value = core.str.add("group_item_", id)
                        main = core.str.add(main, "  %")
                        main = core.str.add(main, group_item_ptr)
                        main = core.str.add(main, " = getelementptr %Group, ptr %")
                        main = core.str.add(main, group_arg.value)
                        main = core.str.add(main, ", i32 0, i32 1, i32 ")
                        main = core.str.add(main, index_arg.value)
                        main = core.str.add(main, "\n  %")
                        main = core.str.add(main, group_item_value)
                        main = core.str.add(main, " = load i32, ptr %")
                        main = core.str.add(main, group_item_ptr)
                        main = core.str.add(main, "\n")
                        exit_value = core.str.add("%", group_item_value)
                    }
                    (out_arg_count == 1) {
                        @out_arg = llvm_resolve(core.group.item(out_value.args, 0), names, values)
                        (out_arg.op == "STRING") {
                            @arg_global = core.str.add("arg_", id)
                            @arg_pointer = core.str.add("arg_ptr_", id)
                            @out_call = core.str.add("out_call_", id)
                            globals = core.str.add(globals, llvm_string_global(arg_global, out_arg.value))
                            main = core.str.add(main, llvm_string_pointer(arg_pointer, arg_global, out_arg.value))
                            main = core.str.add(main, "  %")
                            main = core.str.add(main, out_call)
                            main = core.str.add(main, " = call i32 @")
                            main = core.str.add(main, out_value.name)
                            main = core.str.add(main, "(ptr %")
                            main = core.str.add(main, arg_pointer)
                            main = core.str.add(main, ")\n")
                        }
                        (out_arg.op == "NUMBER") {
                            @number_call = core.str.add("number_call_", id)
                            main = core.str.add(main, "  %")
                            main = core.str.add(main, number_call)
                            main = core.str.add(main, " = call i32 @")
                            main = core.str.add(main, out_value.name)
                            main = core.str.add(main, "(i32 ")
                            main = core.str.add(main, out_arg.value)
                            main = core.str.add(main, ")\n")
                            exit_value = core.str.add("%", number_call)
                        }
                    }
                    (out_arg_count == 2) {
                        @left_arg = llvm_resolve(core.group.item(out_value.args, 0), names, values)
                        @right_arg = llvm_resolve(core.group.item(out_value.args, 1), names, values)
                        (left_arg.op == "NUMBER") {
                            (right_arg.op == "NUMBER") {
                                @math_call = core.str.add("math_call_", id)
                                main = core.str.add(main, "  %")
                                main = core.str.add(main, math_call)
                                main = core.str.add(main, " = call i32 @")
                                main = core.str.add(main, out_value.name)
                                main = core.str.add(main, "(i32 ")
                                main = core.str.add(main, left_arg.value)
                                main = core.str.add(main, ", i32 ")
                                main = core.str.add(main, right_arg.value)
                                main = core.str.add(main, ")\n")
                                exit_value = core.str.add("%", math_call)
                            }
                        }
                    }
                }
                (instruction.value.op == "FIELD") {
                    @owner = instruction.value.value
                    @box_name = ""
                    @box_index = 0
                    @box_count = core.group.count(box_names)
                    drum (box_count) {
                        (box_index < box_count) {
                            (core.group.item(box_names, box_index) == owner.value) { box_name = core.group.item(box_types, box_index) }
                            box_index = box_index + 1
                        }
                    }
                    @field = llvm_box_field(instructions, box_name, instruction.value.name)
                    (field.found == yes) {
                        @field_id = core_num_text(field.index)
                        @field_ptr = core.str.add("box_field_ptr_", id)
                        @field_value = core.str.add("box_field_", id)
                        main = core.str.add(main, "  %")
                        main = core.str.add(main, field_ptr)
                        main = core.str.add(main, " = getelementptr %Box_")
                        main = core.str.add(main, box_name)
                        main = core.str.add(main, ", ptr %")
                        main = core.str.add(main, owner.value)
                        main = core.str.add(main, ", i32 0, i32 ")
                        main = core.str.add(main, field_id)
                        main = core.str.add(main, "\n  %")
                        main = core.str.add(main, field_value)
                        main = core.str.add(main, " = load i32, ptr %")
                        main = core.str.add(main, field_ptr)
                        main = core.str.add(main, "\n")
                        exit_value = core.str.add("%", field_value)
                    }
                }
            }

            (instruction.op == "WRITE") {
                @argument = llvm_resolve(core.group.item(instruction.args, 0), names, values)

                (argument.op == "NUMBER") {
                    (fmt_added == no) {
                        globals = core.str.add(globals, "@fmt = private constant [4 x i8] c\"%d\\0A\\00\"\n")
                        fmt_added = yes
                    }
                    @fmt_ptr = core.str.add("fmt_", id)
                    main = core.str.add(main, "  %")
                    main = core.str.add(main, fmt_ptr)
                    main = core.str.add(main, " = getelementptr [4 x i8], ptr @fmt, i32 0, i32 0\n  call i32 (ptr, ...) @printf(ptr %")
                    main = core.str.add(main, fmt_ptr)
                    main = core.str.add(main, ", i32 ")
                    main = core.str.add(main, argument.value)
                    main = core.str.add(main, ")\n")
                }

                (argument.op == "STRING") {
                    @global_name = core.str.add("text_", id)
                    @pointer_name = core.str.add("text_ptr_", id)
                    globals = core.str.add(globals, llvm_string_global(global_name, argument.value))
                    main = core.str.add(main, llvm_string_pointer(pointer_name, global_name, argument.value))
                    main = core.str.add(main, "  call i32 @puts(ptr %")
                    main = core.str.add(main, pointer_name)
                    main = core.str.add(main, ")\n")
                }

                (argument.op == "CALL") {
                    @call_name = core.str.add("call_", id)
                    main = core.str.add(main, "  %")
                    main = core.str.add(main, call_name)
                    main = core.str.add(main, " = call ptr @")
                    main = core.str.add(main, argument.name)
                    main = core.str.add(main, "()\n  call i32 @puts(ptr %")
                    main = core.str.add(main, call_name)
                    main = core.str.add(main, ")\n")
                }
            }

            (instruction.op == "PROCESS_RUN") {
                @process_argument = llvm_resolve(core.group.item(instruction.args, 0), names, values)
                (process_argument.op == "STRING") {
                    @command_name = core.str.add("command_", id)
                    @command_ptr = core.str.add("command_ptr_", id)
                    @status_name = core.str.add("status_", id)
                    globals = core.str.add(globals, llvm_string_global(command_name, process_argument.value))
                    main = core.str.add(main, llvm_string_pointer(command_ptr, command_name, process_argument.value))
                    main = core.str.add(main, "  %")
                    main = core.str.add(main, status_name)
                    main = core.str.add(main, " = call i32 @system(ptr %")
                    main = core.str.add(main, command_ptr)
                    main = core.str.add(main, ")\n")
                    exit_value = core.str.add("%", status_name)
                }
            }

            index = index + 1
        }
    }

    @text = globals
    text = core.str.add(text, declarations)
    text = core.str.add(text, functions)
    text = core.str.add(text, "define i32 @main() {\nentry:\n")
    text = core.str.add(text, main)
    text = core.str.add(text, "  ret i32 ")
    text = core.str.add(text, exit_value)
    text = core.str.add(text, "\n}\n")

    out LlvmOut {
        text = text
        diagnostics = []
    }
}
