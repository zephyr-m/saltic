use core

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
    kind = ""
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
    body = []
}

LlvmSkillPass = Box {
    found = no
    owner = ""
    args = []
}

LlvmSkillGroupItem = Box {
    found = no
    group = ""
    index = ""
    result = ""
}

LlvmSkillScanner = Box {
    found = no
    source = ""
    lexical = no
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

skill llvm_box_type_id(instructions, box_name) {
    @result = 0
    @next = 1
    @index = 0
    @count = core.group.count(instructions)
    drum (count) {
        (index < count) {
            @instruction = core.group.item(instructions, index)
            (instruction.op == "BOX_DECL") {
                (instruction.name == box_name) { result = next }
                next = next + 1
            }
            index = index + 1
        }
    }
    out result
}

skill llvm_group_value_name(name, index) {
    @text = core.str.add(name, "_value_")
    out core.str.add(text, core_num_text(index))
}

skill llvm_group_item_kind(item) {
    (item.op == "NONE") { out 0 }
    (item.op == "NUMBER") { out 1 }
    (item.op == "STRING") { out 2 }
    (item.op == "PATH") { out 3 }
    (item.op == "BOX") { out 3 }
    (item.op == "GROUP") { out 4 }
    out 0
}

skill llvm_group_item_type(instructions, item, box_names, box_types) {
    @result = 0
    (item.op == "BOX") { result = llvm_box_type_id(instructions, item.name) }
    (item.op == "PATH") {
        @index = 0
        @count = core.group.count(box_names)
        drum (count) {
            (index < count) {
                (core.group.item(box_names, index) == item.value) {
                    result = llvm_box_type_id(instructions, core.group.item(box_types, index))
                }
                index = index + 1
            }
        }
    }
    out result
}

skill llvm_group_store(instructions, pointer, prefix, item, box_names, box_types) {
    @kind = llvm_group_item_kind(item)
    @type = llvm_group_item_type(instructions, item, box_names, box_types)
    @text = "  %"
    text = core.str.add(text, prefix)
    text = core.str.add(text, "_kind = getelementptr %Value, ptr %")
    text = core.str.add(text, pointer)
    text = core.str.add(text, ", i32 0, i32 0\n  store i32 ")
    text = core.str.add(text, core_num_text(kind))
    text = core.str.add(text, ", ptr %")
    text = core.str.add(text, prefix)
    text = core.str.add(text, "_kind\n  %")
    text = core.str.add(text, prefix)
    text = core.str.add(text, "_type = getelementptr %Value, ptr %")
    text = core.str.add(text, pointer)
    text = core.str.add(text, ", i32 0, i32 1\n  store i32 ")
    text = core.str.add(text, core_num_text(type))
    text = core.str.add(text, ", ptr %")
    text = core.str.add(text, prefix)
    text = core.str.add(text, "_type\n  %")
    text = core.str.add(text, prefix)
    text = core.str.add(text, "_data = getelementptr %Value, ptr %")
    text = core.str.add(text, pointer)
    text = core.str.add(text, ", i32 0, i32 2\n")

    (item.op == "NUMBER") {
        text = core.str.add(text, "  store i64 ")
        text = core.str.add(text, item.value)
        text = core.str.add(text, ", ptr %")
        text = core.str.add(text, prefix)
        text = core.str.add(text, "_data\n")
    }
    (item.op == "NONE") {
        text = core.str.add(text, "  store i64 0, ptr %")
        text = core.str.add(text, prefix)
        text = core.str.add(text, "_data\n")
    }
    (item.op == "STRING") {
        @pointer_name = core.str.add(prefix, "_text")
        @global_name = core.str.add(prefix, "_global")
        text = core.str.add(text, llvm_string_pointer(pointer_name, global_name, item.value))
        @data_name = core.str.add(prefix, "_raw")
        text = core.str.add(text, "  %")
        text = core.str.add(text, data_name)
        text = core.str.add(text, " = ptrtoint ptr %")
        text = core.str.add(text, pointer_name)
        text = core.str.add(text, " to i64\n  store i64 %")
        text = core.str.add(text, data_name)
        text = core.str.add(text, ", ptr %")
        text = core.str.add(text, prefix)
        text = core.str.add(text, "_data\n")
    }
    (item.op == "PATH") {
        @data_name = core.str.add(prefix, "_raw")
        text = core.str.add(text, "  %")
        text = core.str.add(text, data_name)
        text = core.str.add(text, " = ptrtoint ptr %")
        text = core.str.add(text, item.value)
        text = core.str.add(text, " to i64\n  store i64 %")
        text = core.str.add(text, data_name)
        text = core.str.add(text, ", ptr %")
        text = core.str.add(text, prefix)
        text = core.str.add(text, "_data\n")
    }
    (item.op == "GROUP") {
        @nested_name = core.str.add(prefix, "_group")
        text = core.str.add(text, "  %")
        text = core.str.add(text, nested_name)
        text = core.str.add(text, " = alloca %Group\n")
        text = core.str.add(text, llvm_group_init_at(instructions, nested_name, item, nested_name, box_names, box_types))
        @data_name = core.str.add(prefix, "_raw")
        text = core.str.add(text, "  %")
        text = core.str.add(text, data_name)
        text = core.str.add(text, " = ptrtoint ptr %")
        text = core.str.add(text, nested_name)
        text = core.str.add(text, " to i64\n  store i64 %")
        text = core.str.add(text, data_name)
        text = core.str.add(text, ", ptr %")
        text = core.str.add(text, prefix)
        text = core.str.add(text, "_data\n")
    }
    out text
}

skill llvm_group_init_at(instructions, pointer, group, prefix, box_names, box_types) {
    @text = "  %"
    text = core.str.add(text, prefix)
    text = core.str.add(text, "_count = getelementptr %Group, ptr %")
    text = core.str.add(text, pointer)
    text = core.str.add(text, ", i32 0, i32 0\n  store i32 ")
    text = core.str.add(text, core_num_text(core.group.count(group.args)))
    text = core.str.add(text, ", ptr %")
    text = core.str.add(text, prefix)
    text = core.str.add(text, "_count\n")
    @index = 0
    @count = core.group.count(group.args)
    drum (count) {
        (index < count) {
            @item = core.group.item(group.args, index)
            @index_text = core_num_text(index)
            @item_pointer = core.str.add(prefix, "_item_")
            item_pointer = core.str.add(item_pointer, index_text)
            text = core.str.add(text, "  %")
            text = core.str.add(text, item_pointer)
            text = core.str.add(text, " = getelementptr %Group, ptr %")
            text = core.str.add(text, pointer)
            text = core.str.add(text, ", i32 0, i32 1, i32 ")
            text = core.str.add(text, index_text)
            text = core.str.add(text, "\n")
            text = core.str.add(text, llvm_group_store(instructions, item_pointer, llvm_group_value_name(prefix, index), item, box_names, box_types))
            index = index + 1
        }
    }
    out text
}

skill llvm_group_init(instructions, name, group, box_names, box_types) {
    @text = "  %"
    text = core.str.add(text, name)
    text = core.str.add(text, " = alloca %Group\n")
    text = core.str.add(text, llvm_group_init_at(instructions, name, group, name, box_names, box_types))
    out text
}

skill llvm_group_runtime() {
    out "define void @group_add(ptr %source, i32 %kind, i32 %type, i64 %data, ptr %target) {\nentry:\n  %source_count_ptr = getelementptr %Group, ptr %source, i32 0, i32 0\n  %source_count = load i32, ptr %source_count_ptr\n  %has_space = icmp slt i32 %source_count, 16\n  %next_count = add i32 %source_count, 1\n  %target_count = select i1 %has_space, i32 %next_count, i32 %source_count\n  %target_count_ptr = getelementptr %Group, ptr %target, i32 0, i32 0\n  store i32 %target_count, ptr %target_count_ptr\n  br label %copy_test\ncopy_test:\n  %copy_index = phi i32 [ 0, %entry ], [ %copy_next, %copy_body ]\n  %copy_more = icmp slt i32 %copy_index, %source_count\n  br i1 %copy_more, label %copy_body, label %append_test\ncopy_body:\n  %source_item_ptr = getelementptr %Group, ptr %source, i32 0, i32 1, i32 %copy_index\n  %source_item = load %Value, ptr %source_item_ptr\n  %target_item_ptr = getelementptr %Group, ptr %target, i32 0, i32 1, i32 %copy_index\n  store %Value %source_item, ptr %target_item_ptr\n  %copy_next = add i32 %copy_index, 1\n  br label %copy_test\nappend_test:\n  br i1 %has_space, label %append, label %done\nappend:\n  %append_ptr = getelementptr %Group, ptr %target, i32 0, i32 1, i32 %source_count\n  %append_kind = getelementptr %Value, ptr %append_ptr, i32 0, i32 0\n  store i32 %kind, ptr %append_kind\n  %append_type = getelementptr %Value, ptr %append_ptr, i32 0, i32 1\n  store i32 %type, ptr %append_type\n  %append_data = getelementptr %Value, ptr %append_ptr, i32 0, i32 2\n  store i64 %data, ptr %append_data\n  br label %done\ndone:\n  ret void\n}\n"
}

skill llvm_group_add(instructions, name, call, box_names, box_types) {
    @source = core.group.item(call.args, 0)
    @value = core.group.item(call.args, 1)
    @kind = llvm_group_item_kind(value)
    @type = llvm_group_item_type(instructions, value, box_names, box_types)
    @text = ""
    @data = value.value
    (value.op == "STRING") {
        @global_name = core.str.add("group_add_", name)
        @pointer_name = core.str.add(global_name, "_ptr")
        text = core.str.add(text, "  %")
        text = core.str.add(text, pointer_name)
        text = core.str.add(text, " = getelementptr [")
        @escaped = llvm_escape_string(value.value)
        text = core.str.add(text, core_num_text(escaped.length))
        text = core.str.add(text, " x i8], ptr @")
        text = core.str.add(text, global_name)
        text = core.str.add(text, ", i32 0, i32 0\n  %")
        @raw_name = core.str.add(global_name, "_raw")
        text = core.str.add(text, raw_name)
        text = core.str.add(text, " = ptrtoint ptr %")
        text = core.str.add(text, pointer_name)
        text = core.str.add(text, " to i64\n")
        data = core.str.add("%", raw_name)
    }
    (value.op == "PATH") {
        @raw_name = core.str.add("group_add_raw_", name)
        text = core.str.add(text, "  %")
        text = core.str.add(text, raw_name)
        text = core.str.add(text, " = ptrtoint ptr %")
        text = core.str.add(text, value.value)
        text = core.str.add(text, " to i64\n")
        data = core.str.add("%", raw_name)
    }
    text = core.str.add(text, "  %")
    text = core.str.add(text, name)
    text = core.str.add(text, " = alloca %Group\n  call void @group_add(ptr %")
    text = core.str.add(text, source.value)
    text = core.str.add(text, ", i32 ")
    text = core.str.add(text, core_num_text(kind))
    text = core.str.add(text, ", i32 ")
    text = core.str.add(text, core_num_text(type))
    text = core.str.add(text, ", i64 ")
    text = core.str.add(text, data)
    text = core.str.add(text, ", ptr %")
    text = core.str.add(text, name)
    text = core.str.add(text, ")\n")
    out text
}

skill llvm_group_item_static(call, names, values) {
    @group_value = llvm_resolve(core.group.item(call.args, 0), names, values)
    @index_value = core.group.item(call.args, 1)
    @result = none
    (group_value.op == "GROUP") {
        @index = 0
        @count = core.group.count(group_value.args)
        drum (count) {
            (index < count) {
                (core_num_text(index) == index_value.value) { result = core.group.item(group_value.args, index) }
                index = index + 1
            }
        }
    }
    (group_value.op == "CALL") {
        (group_value.name == "core.group.add") {
            @source = llvm_resolve(core.group.item(group_value.args, 0), names, values)
            @source_count = core.group.count(source.args)
            (core_num_text(source_count) == index_value.value) {
                result = core.group.item(group_value.args, 1)
            }
            @source_index = 0
            drum (source_count) {
                (source_index < source_count) {
                    (core_num_text(source_index) == index_value.value) { result = core.group.item(source.args, source_index) }
                    source_index = source_index + 1
                }
            }
        }
    }
    out result
}

skill llvm_group_item_assign(name, call, item) {
    @source = core.group.item(call.args, 0)
    @index = core.group.item(call.args, 1)
    @pointer = core.str.add(name, "_value_ptr")
    @data_pointer = core.str.add(name, "_data_ptr")
    @raw = core.str.add(name, "_raw")
    @text = "  %"
    text = core.str.add(text, pointer)
    text = core.str.add(text, " = getelementptr %Group, ptr %")
    text = core.str.add(text, source.value)
    text = core.str.add(text, ", i32 0, i32 1, i32 ")
    text = core.str.add(text, index.value)
    text = core.str.add(text, "\n  %")
    text = core.str.add(text, data_pointer)
    text = core.str.add(text, " = getelementptr %Value, ptr %")
    text = core.str.add(text, pointer)
    text = core.str.add(text, ", i32 0, i32 2\n  %")
    text = core.str.add(text, raw)
    text = core.str.add(text, " = load i64, ptr %")
    text = core.str.add(text, data_pointer)
    text = core.str.add(text, "\n  %")
    text = core.str.add(text, name)
    (item.op == "NUMBER") { text = core.str.add(text, " = trunc i64 %") }
    (item.op == "NUMBER") {
        text = core.str.add(text, raw)
        text = core.str.add(text, " to i32\n")
    }
    @is_number = no
    (item.op == "NUMBER") { is_number = yes }
    (is_number == no) {
        text = core.str.add(text, " = inttoptr i64 %")
        text = core.str.add(text, raw)
        text = core.str.add(text, " to ptr\n")
    }
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
                        @field = core.group.item(instruction.body, field_index)
                        (field.value.op == "STRING") { text = core.str.add(text, "ptr") }
                        (field.value.op == "NUMBER") { text = core.str.add(text, "i32") }
                        (field.value.op == "GROUP") { text = core.str.add(text, "%Group") }
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

skill llvm_box_string_name(name, index) {
    @text = "box_"
    text = core.str.add(text, name)
    text = core.str.add(text, "_field_")
    text = core.str.add(text, core_num_text(index))
    out text
}

skill llvm_group_string_globals(name, group) {
    @text = ""
    @index = 0
    @count = core.group.count(group.args)
    drum (count) {
        (index < count) {
            @item = core.group.item(group.args, index)
            @prefix = llvm_group_value_name(name, index)
            (item.op == "STRING") {
                text = core.str.add(text, llvm_string_global(core.str.add(prefix, "_global"), item.value))
            }
            (item.op == "GROUP") {
                text = core.str.add(text, llvm_group_string_globals(core.str.add(prefix, "_group"), item))
            }
            index = index + 1
        }
    }
    out text
}

skill llvm_box_string_globals(instructions) {
    @text = ""
    @index = 0
    @count = core.group.count(instructions)
    drum (count) {
        (index < count) {
            @instruction = core.group.item(instructions, index)
            (instruction.op == "ASSIGN") {
                (instruction.value.op == "BOX") {
                    @box = instruction.value
                    @declaration = core.group.item(instructions, 0)
                    @decl_index = 0
                    drum (count) {
                        (decl_index < count) {
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
                            (field_value.op == "STRING") {
                                text = core.str.add(text, llvm_string_global(llvm_box_string_name(instruction.name, field_index), field_value.value))
                            }
                            (field_value.op == "GROUP") {
                                @group_name = core.str.add(instruction.name, "_group_")
                                group_name = core.str.add(group_name, core_num_text(field_index))
                                text = core.str.add(text, llvm_group_string_globals(group_name, field_value))
                            }
                            field_index = field_index + 1
                        }
                    }
                }
                (instruction.value.op == "GROUP") {
                    text = core.str.add(text, llvm_group_string_globals(instruction.name, instruction.value))
                }
                (instruction.value.op == "CALL") {
                    @arg_index = 0
                    @arg_count = core.group.count(instruction.value.args)
                    drum (arg_count) {
                        (arg_index < arg_count) {
                            @argument = core.group.item(instruction.value.args, arg_index)
                            (argument.op == "STRING") {
                                @global_name = core.str.add("call_", instruction.name)
                                global_name = core.str.add(global_name, "_arg_")
                                global_name = core.str.add(global_name, core_num_text(arg_index))
                                text = core.str.add(text, llvm_string_global(global_name, argument.value))
                            }
                            arg_index = arg_index + 1
                        }
                    }
                }
                (instruction.value.op == "CALL") {
                    (instruction.value.name == "core.group.add") {
                        @add_value = core.group.item(instruction.value.args, 1)
                        (add_value.op == "STRING") {
                            text = core.str.add(text, llvm_string_global(core.str.add("group_add_", instruction.name), add_value.value))
                        }
                    }
                }
            }
            (instruction.op == "FIELD_SET") {
                (instruction.value.op == "STRING") {
                    @set_name = core.str.add("box_set_", core_num_text(index))
                    text = core.str.add(text, llvm_string_global(set_name, instruction.value.value))
                }
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
            text = core.str.add(text, "\n")
            (field_value.op == "STRING") {
                @pointer_name = core.str.add(name, "_string_")
                pointer_name = core.str.add(pointer_name, index_text)
                text = core.str.add(text, llvm_string_pointer(pointer_name, llvm_box_string_name(name, index), field_value.value))
                text = core.str.add(text, "  store ptr %")
                text = core.str.add(text, pointer_name)
            }
            (field_value.op == "NUMBER") {
                text = core.str.add(text, "  store i32 ")
                text = core.str.add(text, field_value.value)
            }
            (field_value.op == "STRING") {
                text = core.str.add(text, ", ptr %")
                text = core.str.add(text, name)
                text = core.str.add(text, "_field_")
                text = core.str.add(text, index_text)
                text = core.str.add(text, "\n")
            }
            (field_value.op == "NUMBER") {
                text = core.str.add(text, ", ptr %")
                text = core.str.add(text, name)
                text = core.str.add(text, "_field_")
                text = core.str.add(text, index_text)
                text = core.str.add(text, "\n")
            }
            (field_value.op == "GROUP") {
                @group_prefix = core.str.add(name, "_group_")
                group_prefix = core.str.add(group_prefix, index_text)
                @group_pointer = core.str.add(name, "_field_")
                group_pointer = core.str.add(group_pointer, index_text)
                text = core.str.add(text, llvm_group_init_at(instructions, group_pointer, field_value, group_prefix, [], []))
            }
            index = index + 1
        }
    }
    out text
}

skill llvm_box_field(instructions, box_name, field_name) {
    @found = no
    @result = 0
    @kind = ""
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
                                kind = field.value.op
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
        kind = kind
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

skill llvm_box_arg_kind(instructions, box, arg_name) {
    @kind = "NUMBER"
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
    @override_index = 0
    @override_count = core.group.count(box.body)
    drum (override_count) {
        (override_index < override_count) {
            @override = core.group.item(box.body, override_index)
            (override.value.op == "PATH") {
                (override.value.value == arg_name) {
                    @field = llvm_box_field(instructions, box.name, override.name)
                    kind = field.kind
                }
            }
            override_index = override_index + 1
        }
    }
    out kind
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
            @arg_name = core.group.item(instruction.args, arg_index)
            @arg_kind = llvm_box_arg_kind(instructions, box, arg_name)
            (arg_kind == "STRING") { text = core.str.add(text, "ptr %") }
            (arg_kind == "NUMBER") { text = core.str.add(text, "i32 %") }
            text = core.str.add(text, arg_name)
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
            text = core.str.add(text, "\n  store ")
            (field.value.op == "STRING") { text = core.str.add(text, "ptr ") }
            (field.value.op == "NUMBER") { text = core.str.add(text, "i32 ") }
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
    (owner == "") { out LlvmSkillBoxChange { found = no, owner = "", box = "", args = instruction.args, body = instruction.body } }
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
    out LlvmSkillBoxChange { found = found, owner = owner, box = box, args = instruction.args, body = instruction.body }
}

skill llvm_change_arg_kind(instructions, change, arg_name) {
    @kind = "NUMBER"
    @index = 0
    @count = core.group.count(change.body)
    drum (count) {
        (index < count) {
            @body_instruction = core.group.item(change.body, index)
            (body_instruction.op == "FIELD_SET") {
                (body_instruction.value.op == "PATH") {
                    (body_instruction.value.value == arg_name) {
                        @field = llvm_box_field(instructions, change.box, body_instruction.name)
                        kind = field.kind
                    }
                }
            }
            index = index + 1
        }
    }
    out kind
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
            (is_owner == no) {
                @arg_kind = llvm_change_arg_kind(instructions, change, arg_name)
                (arg_kind == "STRING") { text = core.str.add(text, "ptr %") }
                (arg_kind == "NUMBER") { text = core.str.add(text, "i32 %") }
            }
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
                text = core.str.add(text, "\n  store ")
                (field.kind == "STRING") { text = core.str.add(text, "ptr ") }
                (field.kind == "NUMBER") { text = core.str.add(text, "i32 ") }
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

skill llvm_box_change_call(instructions, name, call, change) {
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
            (is_owner == no) {
                @arg_kind = llvm_change_arg_kind(instructions, change, parameter)
                (arg_kind == "STRING") {
                    @global_name = core.str.add("call_", name)
                    global_name = core.str.add(global_name, "_arg_")
                    global_name = core.str.add(global_name, core_num_text(index))
                    @pointer_name = core.str.add(global_name, "_ptr")
                    text = core.str.add(text, "ptr %")
                    text = core.str.add(text, pointer_name)
                }
                (arg_kind == "NUMBER") {
                    text = core.str.add(text, "i32 ")
                    text = core.str.add(text, argument.value)
                }
            }
            (is_owner == yes) { text = core.str.add(text, argument.value) }
            index = index + 1
        }
    }
    text = core.str.add(text, ")\n")
    out text
}

skill llvm_find_skill_box_change(instructions, name) {
    @result = LlvmSkillBoxChange { found = no, owner = "", box = "", args = [], body = [] }
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

skill llvm_skill_pass(instruction) {
    @found = no
    @owner = ""
    @arg_count = core.group.count(instruction.args)
    (arg_count == 1) {
        owner = core.group.item(instruction.args, 0)
        @body_index = 0
        @body_count = core.group.count(instruction.body)
        drum (body_count) {
            (body_index < body_count) {
                @body_instruction = core.group.item(instruction.body, body_index)
                (body_instruction.op == "OUT") {
                    (body_instruction.value.op == "PATH") {
                        (body_instruction.value.value == owner) { found = yes }
                    }
                }
                body_index = body_index + 1
            }
        }
    }
    out LlvmSkillPass { found = found, owner = owner, args = instruction.args }
}

skill llvm_skill_pass_function(instruction, pass) {
    @text = "define ptr @"
    text = core.str.add(text, instruction.name)
    text = core.str.add(text, "(ptr %")
    text = core.str.add(text, pass.owner)
    text = core.str.add(text, ") {\nentry:\n  ret ptr %")
    text = core.str.add(text, pass.owner)
    text = core.str.add(text, "\n}\n")
    out text
}

skill llvm_find_skill_pass(instructions, name) {
    @result = LlvmSkillPass { found = no, owner = "", args = [] }
    @index = 0
    @count = core.group.count(instructions)
    drum (count) {
        (index < count) {
            @instruction = core.group.item(instructions, index)
            (instruction.op == "SKILL") {
                (instruction.name == name) { result = llvm_skill_pass(instruction) }
            }
            index = index + 1
        }
    }
    out result
}

skill llvm_skill_group_item(instruction) {
    @found = no
    @group = ""
    @index_name = ""
    @result = ""
    @body_index = 0
    @body_count = core.group.count(instruction.body)
    drum (body_count) {
        (body_index < body_count) {
            @body_instruction = core.group.item(instruction.body, body_index)
            (body_instruction.op == "ASSIGN") {
                (body_instruction.value.op == "CALL") {
                    (body_instruction.value.name == "core.group.item") {
                        @group_arg = core.group.item(body_instruction.value.args, 0)
                        @index_arg = core.group.item(body_instruction.value.args, 1)
                        (group_arg.op == "PATH") {
                            (index_arg.op == "PATH") {
                                group = group_arg.value
                                index_name = index_arg.value
                                result = body_instruction.name
                            }
                        }
                    }
                }
            }
            body_index = body_index + 1
        }
    }
    (result == "") { out LlvmSkillGroupItem { found = no, group = "", index = "", result = "" } }
    @out_index = 0
    drum (body_count) {
        (out_index < body_count) {
            @body_instruction = core.group.item(instruction.body, out_index)
            (body_instruction.op == "OUT") {
                (body_instruction.value.op == "PATH") {
                    (body_instruction.value.value == result) { found = yes }
                }
            }
            out_index = out_index + 1
        }
    }
    out LlvmSkillGroupItem { found = found, group = group, index = index_name, result = result }
}

skill llvm_skill_group_item_function(instruction, item) {
    @text = "define ptr @"
    text = core.str.add(text, instruction.name)
    text = core.str.add(text, "(ptr %")
    text = core.str.add(text, item.group)
    text = core.str.add(text, ", i32 %")
    text = core.str.add(text, item.index)
    text = core.str.add(text, ", i32 %expected_type) {\nentry:\n  %item_value = getelementptr %Group, ptr %")
    text = core.str.add(text, item.group)
    text = core.str.add(text, ", i32 0, i32 1, i32 %")
    text = core.str.add(text, item.index)
    text = core.str.add(text, "\n  %item_kind_ptr = getelementptr %Value, ptr %item_value, i32 0, i32 0\n  %item_kind = load i32, ptr %item_kind_ptr\n  %item_type_ptr = getelementptr %Value, ptr %item_value, i32 0, i32 1\n  %item_type = load i32, ptr %item_type_ptr\n  %item_is_box = icmp eq i32 %item_kind, 3\n  %item_type_ok = icmp eq i32 %item_type, %expected_type\n  %item_valid = and i1 %item_is_box, %item_type_ok\n  %item_data_ptr = getelementptr %Value, ptr %item_value, i32 0, i32 2\n  %item_data = load i64, ptr %item_data_ptr\n  %item_safe = select i1 %item_valid, i64 %item_data, i64 0\n  %")
    text = core.str.add(text, item.result)
    text = core.str.add(text, " = inttoptr i64 %item_safe to ptr\n  ret ptr %")
    text = core.str.add(text, item.result)
    text = core.str.add(text, "\n}\n")
    out text
}

skill llvm_find_skill_group_item(instructions, name) {
    @result = LlvmSkillGroupItem { found = no, group = "", index = "", result = "" }
    @index = 0
    @count = core.group.count(instructions)
    drum (count) {
        (index < count) {
            @instruction = core.group.item(instructions, index)
            (instruction.op == "SKILL") {
                (instruction.name == name) { result = llvm_skill_group_item(instruction) }
            }
            index = index + 1
        }
    }
    out result
}

skill llvm_group_box_type(group, box_names, box_types) {
    @result = ""
    @item_index = 0
    @item_count = core.group.count(group.args)
    drum (item_count) {
        (item_index < item_count) {
            @item = core.group.item(group.args, item_index)
            (item.op == "PATH") {
                @box_index = 0
                @box_count = core.group.count(box_names)
                drum (box_count) {
                    (box_index < box_count) {
                        (core.group.item(box_names, box_index) == item.value) { result = core.group.item(box_types, box_index) }
                        box_index = box_index + 1
                    }
                }
            }
            item_index = item_index + 1
        }
    }
    out result
}

skill llvm_group_item_call(name, call, type_id) {
    @group = core.group.item(call.args, 0)
    @index = core.group.item(call.args, 1)
    @text = "  %"
    text = core.str.add(text, name)
    text = core.str.add(text, " = call ptr @")
    text = core.str.add(text, call.name)
    text = core.str.add(text, "(ptr %")
    text = core.str.add(text, group.value)
    text = core.str.add(text, ", i32 ")
    text = core.str.add(text, llvm_numeric_operand(index))
    text = core.str.add(text, ", i32 ")
    text = core.str.add(text, core_num_text(type_id))
    text = core.str.add(text, ")\n")
    out text
}

skill llvm_skill_scanner(instruction) {
    @found_group = no
    @found_drum = no
    @arg_count = core.group.count(instruction.args)
    @source = ""
    @lexical = no
    (arg_count == 1) { source = core.group.item(instruction.args, 0) }
    @index = 0
    @count = core.group.count(instruction.body)
    drum (count) {
        (index < count) {
            @body_instruction = core.group.item(instruction.body, index)
            (body_instruction.op == "ASSIGN") {
                (body_instruction.value.op == "GROUP") { found_group = yes }
            }
            (body_instruction.op == "DRUM") { found_drum = yes }
            (body_instruction.op == "DRUM") {
                @drum_index = 0
                @drum_count = core.group.count(body_instruction.body)
                drum (drum_count) {
                    (drum_index < drum_count) {
                        @drum_instruction = core.group.item(body_instruction.body, drum_index)
                        (drum_instruction.op == "ASSIGN") {
                            (drum_instruction.value.op == "CALL") {
                                (drum_instruction.value.name == "core.str.slice") { lexical = yes }
                            }
                        }
                        drum_index = drum_index + 1
                    }
                }
            }
            index = index + 1
        }
    }
    @found = no
    (found_group == yes) {
        (found_drum == yes) {
            (arg_count == 1) { found = yes }
        }
    }
    out LlvmSkillScanner { found = found, source = source, lexical = lexical }
}

skill llvm_skill_scanner_function(instructions, instruction, scanner) {
    @token_box = llvm_box_for_field(instructions, "col")
    @token_type = llvm_box_type_id(instructions, token_box)
    @text = llvm_string_global("scanner_kind", "CHAR")
    text = core.str.add(text, "define ptr @")
    text = core.str.add(text, instruction.name)
    text = core.str.add(text, "(ptr %")
    text = core.str.add(text, scanner.source)
    text = core.str.add(text, ") {\nentry:\n  %length_raw = call i64 @strlen(ptr %")
    text = core.str.add(text, scanner.source)
    text = core.str.add(text, ")\n  %length = trunc i64 %length_raw to i32\n  %tokens_start = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Group, ptr null, i32 1) to i64))\n  %tokens_start_count = getelementptr %Group, ptr %tokens_start, i32 0, i32 0\n  store i32 0, ptr %tokens_start_count\n  %kind = getelementptr [5 x i8], ptr @scanner_kind, i32 0, i32 0\n  br label %scan_test\nscan_test:\n  %scan_index = phi i32 [ 0, %entry ], [ %scan_next_index, %scan_body ]\n  %scan_tokens = phi ptr [ %tokens_start, %entry ], [ %scan_next_tokens, %scan_body ]\n  %scan_more = icmp slt i32 %scan_index, %length\n  br i1 %scan_more, label %scan_body, label %scan_done\nscan_body:\n  %source_char_ptr = getelementptr i8, ptr %")
    text = core.str.add(text, scanner.source)
    text = core.str.add(text, ", i32 %scan_index\n  %source_char = load i8, ptr %source_char_ptr\n  %char = call ptr @malloc(i64 2)\n  store i8 %source_char, ptr %char\n  %char_end = getelementptr i8, ptr %char, i32 1\n  store i8 0, ptr %char_end\n  %token = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Box_")
    text = core.str.add(text, token_box)
    text = core.str.add(text, ", ptr null, i32 1) to i64))\n  %col = add i32 %scan_index, 1\n  call void @token_make(ptr %kind, ptr %char, i32 1, i32 %col, ptr %token)\n  %scan_next_tokens = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Group, ptr null, i32 1) to i64))\n  %token_raw = ptrtoint ptr %token to i64\n  call void @group_add(ptr %scan_tokens, i32 3, i32 ")
    text = core.str.add(text, core_num_text(token_type))
    text = core.str.add(text, ", i64 %token_raw, ptr %scan_next_tokens)\n  %scan_next_index = add i32 %scan_index, 1\n  br label %scan_test\nscan_done:\n  ret ptr %scan_tokens\n}\n")
    out text
}

skill llvm_lex_string_helper(token_box, token_type) {
    @text = "%LexStep = type { ptr, i32 }\n"
    text = core.str.add(text, "define ptr @lex_read_string(ptr %source, i32 %start, i32 %line, i32 %col, ptr %tokens) {\nentry:\n  %length_raw = call i64 @strlen(ptr %source)\n  %length = trunc i64 %length_raw to i32\n  %capacity = sub i32 %length, %start\n  %capacity64 = zext i32 %capacity to i64\n  %value = call ptr @malloc(i64 %capacity64)\n  %read_start = add i32 %start, 1\n  br label %string_test\nstring_test:\n  %read = phi i32 [ %read_start, %entry ], [ %plain_next, %string_plain_store ], [ %escape_next, %string_escape_set ], [ %decode_next, %string_decode ]\n  %write = phi i32 [ 0, %entry ], [ %plain_write, %string_plain_store ], [ %write, %string_escape_set ], [ %decode_write, %string_decode ]\n  %escaped = phi i1 [ false, %entry ], [ false, %string_plain_store ], [ true, %string_escape_set ], [ false, %string_decode ]\n  %inside = icmp slt i32 %read, %length\n  br i1 %inside, label %string_char, label %string_error\nstring_char:\n  %char_ptr = getelementptr i8, ptr %source, i32 %read\n  %char = load i8, ptr %char_ptr\n  br i1 %escaped, label %string_decode, label %string_plain\nstring_decode:\n  %is_n = icmp eq i8 %char, 110\n  %is_t = icmp eq i8 %char, 116\n  %decoded_n = select i1 %is_n, i8 10, i8 %char\n  %decoded = select i1 %is_t, i8 9, i8 %decoded_n\n  %decode_ptr = getelementptr i8, ptr %value, i32 %write\n  store i8 %decoded, ptr %decode_ptr\n  %decode_next = add i32 %read, 1\n  %decode_write = add i32 %write, 1\n  br label %string_test\nstring_plain:\n  %is_escape = icmp eq i8 %char, 92\n  br i1 %is_escape, label %string_escape_set, label %string_quote_test\nstring_escape_set:\n  %escape_next = add i32 %read, 1\n  br label %string_test\nstring_quote_test:\n  %is_quote = icmp eq i8 %char, 34\n  br i1 %is_quote, label %string_closed, label %string_line_test\nstring_line_test:\n  %is_line = icmp eq i8 %char, 10\n  br i1 %is_line, label %string_error, label %string_plain_store\nstring_plain_store:\n  %plain_ptr = getelementptr i8, ptr %value, i32 %write\n  store i8 %char, ptr %plain_ptr\n  %plain_next = add i32 %read, 1\n  %plain_write = add i32 %write, 1\n  br label %string_test\nstring_closed:\n  %closed_end = add i32 %read, 1\n  br label %string_finish\nstring_error:\n  br label %string_finish\nstring_finish:\n  %end = phi i32 [ %closed_end, %string_closed ], [ %read, %string_error ]\n  %kind = phi ptr [ @lex_string_kind, %string_closed ], [ @lex_string_error_kind, %string_error ]\n  %zero_ptr = getelementptr i8, ptr %value, i32 %write\n  store i8 0, ptr %zero_ptr\n  %token = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Box_")
    text = core.str.add(text, token_box)
    text = core.str.add(text, ", ptr null, i32 1) to i64))\n  call void @token_make(ptr %kind, ptr %value, i32 %line, i32 %col, ptr %token)\n  %next_tokens = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Group, ptr null, i32 1) to i64))\n  %token_raw = ptrtoint ptr %token to i64\n  call void @group_add(ptr %tokens, i32 3, i32 ")
    text = core.str.add(text, core_num_text(token_type))
    text = core.str.add(text, ", i64 %token_raw, ptr %next_tokens)\n  %step = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%LexStep, ptr null, i32 1) to i64))\n  %step_tokens = getelementptr %LexStep, ptr %step, i32 0, i32 0\n  store ptr %next_tokens, ptr %step_tokens\n  %step_end = getelementptr %LexStep, ptr %step, i32 0, i32 1\n  store i32 %end, ptr %step_end\n  ret ptr %step\n}\n")
    out text
}

skill llvm_skill_lex_function(instructions, instruction, scanner) {
    @token_box = llvm_box_for_field(instructions, "col")
    @token_type = llvm_box_type_id(instructions, token_box)
    @text = llvm_string_global("lex_program_word", "program")
    text = core.str.add(text, llvm_string_global("lex_program_kind", "PROGRAM"))
    text = core.str.add(text, llvm_string_global("lex_skill_word", "skill"))
    text = core.str.add(text, llvm_string_global("lex_skill_kind", "SKILL"))
    text = core.str.add(text, llvm_string_global("lex_use_word", "use"))
    text = core.str.add(text, llvm_string_global("lex_use_kind", "USE"))
    text = core.str.add(text, llvm_string_global("lex_box_word", "Box"))
    text = core.str.add(text, llvm_string_global("lex_box_kind", "BOX"))
    text = core.str.add(text, llvm_string_global("lex_enum_word", "enum"))
    text = core.str.add(text, llvm_string_global("lex_enum_kind", "ENUM"))
    text = core.str.add(text, llvm_string_global("lex_out_word", "out"))
    text = core.str.add(text, llvm_string_global("lex_out_kind", "OUT"))
    text = core.str.add(text, llvm_string_global("lex_drum_word", "drum"))
    text = core.str.add(text, llvm_string_global("lex_drum_kind", "DRUM"))
    text = core.str.add(text, llvm_string_global("lex_rescue_word", "rescue"))
    text = core.str.add(text, llvm_string_global("lex_rescue_kind", "RESCUE"))
    text = core.str.add(text, llvm_string_global("lex_yes_word", "yes"))
    text = core.str.add(text, llvm_string_global("lex_yes_kind", "YES"))
    text = core.str.add(text, llvm_string_global("lex_no_word", "no"))
    text = core.str.add(text, llvm_string_global("lex_no_kind", "NO"))
    text = core.str.add(text, llvm_string_global("lex_none_word", "none"))
    text = core.str.add(text, llvm_string_global("lex_none_kind", "NONE"))
    text = core.str.add(text, llvm_string_global("lex_ident_kind", "IDENT"))
    text = core.str.add(text, llvm_string_global("lex_number_kind", "NUMBER"))
    text = core.str.add(text, llvm_string_global("lex_string_kind", "STRING"))
    text = core.str.add(text, llvm_string_global("lex_string_error_kind", "ERROR_UNTERMINATED_STRING"))
    text = core.str.add(text, llvm_string_global("lex_at_kind", "AT"))
    text = core.str.add(text, llvm_string_global("lex_lparen_kind", "LPAREN"))
    text = core.str.add(text, llvm_string_global("lex_rparen_kind", "RPAREN"))
    text = core.str.add(text, llvm_string_global("lex_lbrace_kind", "LBRACE"))
    text = core.str.add(text, llvm_string_global("lex_rbrace_kind", "RBRACE"))
    text = core.str.add(text, llvm_string_global("lex_lbracket_kind", "LBRACKET"))
    text = core.str.add(text, llvm_string_global("lex_rbracket_kind", "RBRACKET"))
    text = core.str.add(text, llvm_string_global("lex_assign_kind", "ASSIGN"))
    text = core.str.add(text, llvm_string_global("lex_eq_kind", "EQ"))
    text = core.str.add(text, llvm_string_global("lex_arrow_kind", "ARROW"))
    text = core.str.add(text, llvm_string_global("lex_plus_kind", "PLUS"))
    text = core.str.add(text, llvm_string_global("lex_minus_kind", "MINUS"))
    text = core.str.add(text, llvm_string_global("lex_star_kind", "STAR"))
    text = core.str.add(text, llvm_string_global("lex_slash_kind", "SLASH"))
    text = core.str.add(text, llvm_string_global("lex_gt_kind", "GT"))
    text = core.str.add(text, llvm_string_global("lex_lt_kind", "LT"))
    text = core.str.add(text, llvm_string_global("lex_dot_kind", "DOT"))
    text = core.str.add(text, llvm_string_global("lex_comma_kind", "COMMA"))
    text = core.str.add(text, llvm_string_global("lex_unknown_kind", "UNKNOWN"))
    text = core.str.add(text, llvm_lex_string_helper(token_box, token_type))
    text = core.str.add(text, "define ptr @")
    text = core.str.add(text, instruction.name)
    text = core.str.add(text, "(ptr %")
    text = core.str.add(text, scanner.source)
    text = core.str.add(text, ") {\nentry:\n  %length_raw = call i64 @strlen(ptr %")
    text = core.str.add(text, scanner.source)
    text = core.str.add(text, ")\n  %length = trunc i64 %length_raw to i32\n  %tokens_start = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Group, ptr null, i32 1) to i64))\n  %tokens_start_count = getelementptr %Group, ptr %tokens_start, i32 0, i32 0\n  store i32 0, ptr %tokens_start_count\n  %program_word = getelementptr [8 x i8], ptr @lex_program_word, i32 0, i32 0\n  %program_kind = getelementptr [8 x i8], ptr @lex_program_kind, i32 0, i32 0\n  %ident_kind = getelementptr [6 x i8], ptr @lex_ident_kind, i32 0, i32 0\n  %number_kind = getelementptr [7 x i8], ptr @lex_number_kind, i32 0, i32 0\n  %assign_kind = getelementptr [7 x i8], ptr @lex_assign_kind, i32 0, i32 0\n  %unknown_kind = getelementptr [8 x i8], ptr @lex_unknown_kind, i32 0, i32 0\n  br label %lex_test\nlex_test:\n  %lex_index = phi i32 [ 0, %entry ], [ %space_index, %lex_space ], [ %word_end, %lex_word_emit ], [ %number_end, %lex_number_emit ], [ %symbol_index, %lex_symbol_emit ], [ %comment_end, %lex_comment_done ]\n  %lex_line = phi i32 [ 1, %entry ], [ %space_line, %lex_space ], [ %word_line, %lex_word_emit ], [ %number_line, %lex_number_emit ], [ %symbol_line, %lex_symbol_emit ], [ %comment_line, %lex_comment_done ]\n  %lex_col = phi i32 [ 1, %entry ], [ %space_col, %lex_space ], [ %word_col, %lex_word_emit ], [ %number_col, %lex_number_emit ], [ %symbol_col, %lex_symbol_emit ], [ %comment_col, %lex_comment_done ]\n  %lex_tokens = phi ptr [ %tokens_start, %entry ], [ %lex_tokens, %lex_space ], [ %word_tokens, %lex_word_emit ], [ %number_tokens, %lex_number_emit ], [ %symbol_tokens, %lex_symbol_emit ], [ %lex_tokens, %lex_comment_done ]\n  %lex_more = icmp slt i32 %lex_index, %length\n  br i1 %lex_more, label %lex_char, label %lex_done\nlex_char:\n  %lex_char_ptr = getelementptr i8, ptr %")
    text = core.str.add(text, scanner.source)
    text = core.str.add(text, ", i32 %lex_index\n  %lex_char_value = load i8, ptr %lex_char_ptr\n  %lex_char_int = zext i8 %lex_char_value to i32\n  %is_space_ascii = icmp eq i32 %lex_char_int, 32\n  %is_tab_ascii = icmp eq i32 %lex_char_int, 9\n  %is_line_ascii = icmp eq i32 %lex_char_int, 10\n  %is_space_a = or i1 %is_space_ascii, %is_tab_ascii\n  %is_space = or i1 %is_space_a, %is_line_ascii\n  br i1 %is_space, label %lex_space, label %lex_classify\nlex_space:\n  %space_index = add i32 %lex_index, 1\n  %space_line_next = add i32 %lex_line, 1\n  %space_line = select i1 %is_line_ascii, i32 %space_line_next, i32 %lex_line\n  %space_col_next = add i32 %lex_col, 1\n  %space_col = select i1 %is_line_ascii, i32 1, i32 %space_col_next\n  br label %lex_test\nlex_classify:\n  %letter_raw = call i32 @isalpha(i32 %lex_char_int)\n  %underscore = icmp eq i32 %lex_char_int, 95\n  %letter = icmp ne i32 %letter_raw, 0\n  %word_start = or i1 %letter, %underscore\n  br i1 %word_start, label %lex_word_test, label %lex_digit_start\nlex_digit_start:\n  %digit_raw = call i32 @isdigit(i32 %lex_char_int)\n  %digit = icmp ne i32 %digit_raw, 0\n  br i1 %digit, label %lex_number_test, label %lex_special\nlex_special:\n  %special_is_quote = icmp eq i32 %lex_char_int, 34\n  br i1 %special_is_quote, label %lex_string, label %lex_comment_check\nlex_string:\n  %string_step = call ptr @lex_read_string(ptr %source, i32 %lex_index, i32 %lex_line, i32 %lex_col, ptr %lex_tokens)\n  %string_tokens_ptr = getelementptr %LexStep, ptr %string_step, i32 0, i32 0\n  %string_tokens = load ptr, ptr %string_tokens_ptr\n  %string_end_ptr = getelementptr %LexStep, ptr %string_step, i32 0, i32 1\n  %string_end = load i32, ptr %string_end_ptr\n  %string_width = sub i32 %string_end, %lex_index\n  %string_col = add i32 %lex_col, %string_width\n  %string_line = add i32 %lex_line, 0\n  br label %lex_test\nlex_comment_check:\n  %special_next_ptr = getelementptr i8, ptr %lex_char_ptr, i32 1\n  %special_next_value = load i8, ptr %special_next_ptr\n  %special_next_int = zext i8 %special_next_value to i32\n  %special_is_slash = icmp eq i32 %lex_char_int, 47\n  %special_next_slash = icmp eq i32 %special_next_int, 47\n  %special_is_comment = and i1 %special_is_slash, %special_next_slash\n  br i1 %special_is_comment, label %lex_comment_start, label %lex_symbol\nlex_comment_start:\n  %comment_start = add i32 %lex_index, 2\n  br label %lex_comment_test\nlex_comment_test:\n  %comment_end = phi i32 [ %comment_start, %lex_comment_start ], [ %comment_next, %lex_comment_body ]\n  %comment_in = icmp slt i32 %comment_end, %length\n  br i1 %comment_in, label %lex_comment_char, label %lex_comment_done\nlex_comment_char:\n  %comment_offset = sub i32 %comment_end, %lex_index\n  %comment_char_ptr = getelementptr i8, ptr %lex_char_ptr, i32 %comment_offset\n  %comment_char_value = load i8, ptr %comment_char_ptr\n  %comment_is_line = icmp eq i8 %comment_char_value, 10\n  br i1 %comment_is_line, label %lex_comment_done, label %lex_comment_body\nlex_comment_body:\n  %comment_next = add i32 %comment_end, 1\n  br label %lex_comment_test\nlex_comment_done:\n  %comment_width = sub i32 %comment_end, %lex_index\n  %comment_col = add i32 %lex_col, %comment_width\n  %comment_line = add i32 %lex_line, 0\n  br label %lex_test\nlex_word_test:\n  %word_end = phi i32 [ %lex_index, %lex_classify ], [ %word_next, %lex_word_body ]\n  %word_in = icmp slt i32 %word_end, %length\n  br i1 %word_in, label %lex_word_char, label %lex_word_done\nlex_word_char:\n  %word_char_ptr = getelementptr i8, ptr %")
    text = core.str.add(text, scanner.source)
    text = core.str.add(text, ", i32 %word_end\n  %word_char_value = load i8, ptr %word_char_ptr\n  %word_char_int = zext i8 %word_char_value to i32\n  %word_alnum_raw = call i32 @isalnum(i32 %word_char_int)\n  %word_alnum = icmp ne i32 %word_alnum_raw, 0\n  %word_under = icmp eq i32 %word_char_int, 95\n  %word_keep = or i1 %word_alnum, %word_under\n  br i1 %word_keep, label %lex_word_body, label %lex_word_done\nlex_word_body:\n  %word_next = add i32 %word_end, 1\n  br label %lex_word_test\nlex_word_done:\n  %word_width = sub i32 %word_end, %lex_index\n  %word_size = add i32 %word_width, 1\n  %word_size64 = zext i32 %word_size to i64\n  %word_width64 = zext i32 %word_width to i64\n  %word = call ptr @malloc(i64 %word_size64)\n  call ptr @memcpy(ptr %word, ptr %lex_char_ptr, i64 %word_width64)\n  %word_zero_ptr = getelementptr i8, ptr %word, i32 %word_width\n  store i8 0, ptr %word_zero_ptr\n  %word_program_cmp = call i32 @strcmp(ptr %word, ptr %program_word)\n  %word_is_program = icmp eq i32 %word_program_cmp, 0\n  %word_skill_cmp = call i32 @strcmp(ptr %word, ptr @lex_skill_word)\n  %word_is_skill = icmp eq i32 %word_skill_cmp, 0\n  %word_use_cmp = call i32 @strcmp(ptr %word, ptr @lex_use_word)\n  %word_is_use = icmp eq i32 %word_use_cmp, 0\n  %word_box_cmp = call i32 @strcmp(ptr %word, ptr @lex_box_word)\n  %word_is_box = icmp eq i32 %word_box_cmp, 0\n  %word_enum_cmp = call i32 @strcmp(ptr %word, ptr @lex_enum_word)\n  %word_is_enum = icmp eq i32 %word_enum_cmp, 0\n  %word_out_cmp = call i32 @strcmp(ptr %word, ptr @lex_out_word)\n  %word_is_out = icmp eq i32 %word_out_cmp, 0\n  %word_drum_cmp = call i32 @strcmp(ptr %word, ptr @lex_drum_word)\n  %word_is_drum = icmp eq i32 %word_drum_cmp, 0\n  %word_rescue_cmp = call i32 @strcmp(ptr %word, ptr @lex_rescue_word)\n  %word_is_rescue = icmp eq i32 %word_rescue_cmp, 0\n  %word_yes_cmp = call i32 @strcmp(ptr %word, ptr @lex_yes_word)\n  %word_is_yes = icmp eq i32 %word_yes_cmp, 0\n  %word_no_cmp = call i32 @strcmp(ptr %word, ptr @lex_no_word)\n  %word_is_no = icmp eq i32 %word_no_cmp, 0\n  %word_none_cmp = call i32 @strcmp(ptr %word, ptr @lex_none_word)\n  %word_is_none = icmp eq i32 %word_none_cmp, 0\n  %word_kind_none = select i1 %word_is_none, ptr @lex_none_kind, ptr %ident_kind\n  %word_kind_no = select i1 %word_is_no, ptr @lex_no_kind, ptr %word_kind_none\n  %word_kind_yes = select i1 %word_is_yes, ptr @lex_yes_kind, ptr %word_kind_no\n  %word_kind_rescue = select i1 %word_is_rescue, ptr @lex_rescue_kind, ptr %word_kind_yes\n  %word_kind_drum = select i1 %word_is_drum, ptr @lex_drum_kind, ptr %word_kind_rescue\n  %word_kind_out = select i1 %word_is_out, ptr @lex_out_kind, ptr %word_kind_drum\n  %word_kind_enum = select i1 %word_is_enum, ptr @lex_enum_kind, ptr %word_kind_out\n  %word_kind_box = select i1 %word_is_box, ptr @lex_box_kind, ptr %word_kind_enum\n  %word_kind_use = select i1 %word_is_use, ptr @lex_use_kind, ptr %word_kind_box\n  %word_kind_skill = select i1 %word_is_skill, ptr @lex_skill_kind, ptr %word_kind_use\n  %word_kind = select i1 %word_is_program, ptr %program_kind, ptr %word_kind_skill\n  %word_token = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Box_")
    text = core.str.add(text, token_box)
    text = core.str.add(text, ", ptr null, i32 1) to i64))\n  call void @token_make(ptr %word_kind, ptr %word, i32 %lex_line, i32 %lex_col, ptr %word_token)\n  %word_tokens = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Group, ptr null, i32 1) to i64))\n  %word_token_raw = ptrtoint ptr %word_token to i64\n  call void @group_add(ptr %lex_tokens, i32 3, i32 ")
    text = core.str.add(text, core_num_text(token_type))
    text = core.str.add(text, ", i64 %word_token_raw, ptr %word_tokens)\n  %word_col = add i32 %lex_col, %word_width\n  %word_line = add i32 %lex_line, 0\n  br label %lex_word_emit\nlex_word_emit:\n  br label %lex_test\nlex_number_test:\n  %number_end = phi i32 [ %lex_index, %lex_digit_start ], [ %number_next, %lex_number_body ]\n  %number_in = icmp slt i32 %number_end, %length\n  br i1 %number_in, label %lex_number_char, label %lex_number_done\nlex_number_char:\n  %number_char_ptr = getelementptr i8, ptr %")
    text = core.str.add(text, scanner.source)
    text = core.str.add(text, ", i32 %number_end\n  %number_char_value = load i8, ptr %number_char_ptr\n  %number_char_int = zext i8 %number_char_value to i32\n  %number_digit_raw = call i32 @isdigit(i32 %number_char_int)\n  %number_keep = icmp ne i32 %number_digit_raw, 0\n  br i1 %number_keep, label %lex_number_body, label %lex_number_done\nlex_number_body:\n  %number_next = add i32 %number_end, 1\n  br label %lex_number_test\nlex_number_done:\n  %number_width = sub i32 %number_end, %lex_index\n  %number_size = add i32 %number_width, 1\n  %number_size64 = zext i32 %number_size to i64\n  %number_width64 = zext i32 %number_width to i64\n  %number = call ptr @malloc(i64 %number_size64)\n  call ptr @memcpy(ptr %number, ptr %lex_char_ptr, i64 %number_width64)\n  %number_zero_ptr = getelementptr i8, ptr %number, i32 %number_width\n  store i8 0, ptr %number_zero_ptr\n  %number_token = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Box_")
    text = core.str.add(text, token_box)
    text = core.str.add(text, ", ptr null, i32 1) to i64))\n  call void @token_make(ptr %number_kind, ptr %number, i32 %lex_line, i32 %lex_col, ptr %number_token)\n  %number_tokens = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Group, ptr null, i32 1) to i64))\n  %number_token_raw = ptrtoint ptr %number_token to i64\n  call void @group_add(ptr %lex_tokens, i32 3, i32 ")
    text = core.str.add(text, core_num_text(token_type))
    text = core.str.add(text, ", i64 %number_token_raw, ptr %number_tokens)\n  %number_col = add i32 %lex_col, %number_width\n  %number_line = add i32 %lex_line, 0\n  br label %lex_number_emit\nlex_number_emit:\n  br label %lex_test\nlex_symbol:\n  %symbol_next_ptr = getelementptr i8, ptr %lex_char_ptr, i32 1\n  %symbol_next_value = load i8, ptr %symbol_next_ptr\n  %symbol_next_int = zext i8 %symbol_next_value to i32\n  %symbol_is_assign_head = icmp eq i32 %lex_char_int, 61\n  %symbol_next_is_assign = icmp eq i32 %symbol_next_int, 61\n  %symbol_next_is_arrow = icmp eq i32 %symbol_next_int, 62\n  %symbol_is_eq = and i1 %symbol_is_assign_head, %symbol_next_is_assign\n  %symbol_is_arrow = and i1 %symbol_is_assign_head, %symbol_next_is_arrow\n  %symbol_is_two = or i1 %symbol_is_eq, %symbol_is_arrow\n  %symbol_width = select i1 %symbol_is_two, i32 2, i32 1\n  %symbol_value = call ptr @malloc(i64 3)\n  store i8 %lex_char_value, ptr %symbol_value\n  %symbol_second = getelementptr i8, ptr %symbol_value, i32 1\n  store i8 %symbol_next_value, ptr %symbol_second\n  %symbol_zero = getelementptr i8, ptr %symbol_value, i32 %symbol_width\n  store i8 0, ptr %symbol_zero\n  %symbol_is_at = icmp eq i32 %lex_char_int, 64\n  %symbol_is_lparen = icmp eq i32 %lex_char_int, 40\n  %symbol_is_rparen = icmp eq i32 %lex_char_int, 41\n  %symbol_is_lbrace = icmp eq i32 %lex_char_int, 123\n  %symbol_is_rbrace = icmp eq i32 %lex_char_int, 125\n  %symbol_is_lbracket = icmp eq i32 %lex_char_int, 91\n  %symbol_is_rbracket = icmp eq i32 %lex_char_int, 93\n  %symbol_is_assign = icmp eq i32 %lex_char_int, 61\n  %symbol_is_plus = icmp eq i32 %lex_char_int, 43\n  %symbol_is_minus = icmp eq i32 %lex_char_int, 45\n  %symbol_is_star = icmp eq i32 %lex_char_int, 42\n  %symbol_is_slash = icmp eq i32 %lex_char_int, 47\n  %symbol_is_gt = icmp eq i32 %lex_char_int, 62\n  %symbol_is_lt = icmp eq i32 %lex_char_int, 60\n  %symbol_is_dot = icmp eq i32 %lex_char_int, 46\n  %symbol_is_comma = icmp eq i32 %lex_char_int, 44\n  %symbol_kind_comma = select i1 %symbol_is_comma, ptr @lex_comma_kind, ptr %unknown_kind\n  %symbol_kind_dot = select i1 %symbol_is_dot, ptr @lex_dot_kind, ptr %symbol_kind_comma\n  %symbol_kind_lt = select i1 %symbol_is_lt, ptr @lex_lt_kind, ptr %symbol_kind_dot\n  %symbol_kind_gt = select i1 %symbol_is_gt, ptr @lex_gt_kind, ptr %symbol_kind_lt\n  %symbol_kind_slash = select i1 %symbol_is_slash, ptr @lex_slash_kind, ptr %symbol_kind_gt\n  %symbol_kind_star = select i1 %symbol_is_star, ptr @lex_star_kind, ptr %symbol_kind_slash\n  %symbol_kind_minus = select i1 %symbol_is_minus, ptr @lex_minus_kind, ptr %symbol_kind_star\n  %symbol_kind_plus = select i1 %symbol_is_plus, ptr @lex_plus_kind, ptr %symbol_kind_minus\n  %symbol_kind_assign = select i1 %symbol_is_assign, ptr %assign_kind, ptr %symbol_kind_plus\n  %symbol_kind_rbracket = select i1 %symbol_is_rbracket, ptr @lex_rbracket_kind, ptr %symbol_kind_assign\n  %symbol_kind_lbracket = select i1 %symbol_is_lbracket, ptr @lex_lbracket_kind, ptr %symbol_kind_rbracket\n  %symbol_kind_rbrace = select i1 %symbol_is_rbrace, ptr @lex_rbrace_kind, ptr %symbol_kind_lbracket\n  %symbol_kind_lbrace = select i1 %symbol_is_lbrace, ptr @lex_lbrace_kind, ptr %symbol_kind_rbrace\n  %symbol_kind_rparen = select i1 %symbol_is_rparen, ptr @lex_rparen_kind, ptr %symbol_kind_lbrace\n  %symbol_kind_lparen = select i1 %symbol_is_lparen, ptr @lex_lparen_kind, ptr %symbol_kind_rparen\n  %symbol_kind_one = select i1 %symbol_is_at, ptr @lex_at_kind, ptr %symbol_kind_lparen\n  %symbol_kind_eq = select i1 %symbol_is_eq, ptr @lex_eq_kind, ptr %symbol_kind_one\n  %symbol_kind = select i1 %symbol_is_arrow, ptr @lex_arrow_kind, ptr %symbol_kind_eq\n  %symbol_token = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Box_")
    text = core.str.add(text, token_box)
    text = core.str.add(text, ", ptr null, i32 1) to i64))\n  call void @token_make(ptr %symbol_kind, ptr %symbol_value, i32 %lex_line, i32 %lex_col, ptr %symbol_token)\n  %symbol_tokens = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Group, ptr null, i32 1) to i64))\n  %symbol_token_raw = ptrtoint ptr %symbol_token to i64\n  call void @group_add(ptr %lex_tokens, i32 3, i32 ")
    text = core.str.add(text, core_num_text(token_type))
    text = core.str.add(text, ", i64 %symbol_token_raw, ptr %symbol_tokens)\n  %symbol_index = add i32 %lex_index, %symbol_width\n  %symbol_col = add i32 %lex_col, %symbol_width\n  %symbol_line = add i32 %lex_line, 0\n  br label %lex_symbol_emit\nlex_symbol_emit:\n  br label %lex_test\nlex_done:\n  ret ptr %lex_tokens\n}\n")
    out text
}

skill llvm_find_skill_scanner(instructions, name) {
    @result = LlvmSkillScanner { found = no, source = "", lexical = no }
    @index = 0
    @count = core.group.count(instructions)
    drum (count) {
        (index < count) {
            @instruction = core.group.item(instructions, index)
            (instruction.op == "SKILL") {
                (instruction.name == name) { result = llvm_skill_scanner(instruction) }
            }
            index = index + 1
        }
    }
    out result
}

skill llvm_scanner_call(name, call) {
    @source = core.group.item(call.args, 0)
    @pointer = core.str.add("call_", name)
    pointer = core.str.add(pointer, "_arg_0_ptr")
    @text = "  %"
    text = core.str.add(text, name)
    text = core.str.add(text, " = call ptr @")
    text = core.str.add(text, call.name)
    text = core.str.add(text, "(ptr %")
    text = core.str.add(text, pointer)
    text = core.str.add(text, ")\n")
    out text
}

skill llvm_box_pass_call(name, call) {
    @source = core.group.item(call.args, 0)
    @text = "  %"
    text = core.str.add(text, name)
    text = core.str.add(text, " = call ptr @")
    text = core.str.add(text, call.name)
    text = core.str.add(text, "(ptr %")
    text = core.str.add(text, source.value)
    text = core.str.add(text, ")\n")
    out text
}

skill llvm_box_call(instructions, name, call, box) {
    @text = "  %"
    text = core.str.add(text, name)
    text = core.str.add(text, " = alloca %Box_")
    text = core.str.add(text, box.name)
    text = core.str.add(text, "\n  call void @")
    text = core.str.add(text, call.name)
    text = core.str.add(text, "(")
    @index = 0
    @count = core.group.count(call.args)
    drum (count) {
        (index < count) {
            (index > 0) { text = core.str.add(text, ", ") }
            @argument = core.group.item(call.args, index)
            @parameter_kind = llvm_box_arg_kind(instructions, box, argument.value)
            @skill_index = 0
            @skill_count = core.group.count(instructions)
            drum (skill_count) {
                (skill_index < skill_count) {
                    @candidate_skill = core.group.item(instructions, skill_index)
                    (candidate_skill.op == "SKILL") {
                        (candidate_skill.name == call.name) {
                            @parameter_name = core.group.item(candidate_skill.args, index)
                            parameter_kind = llvm_box_arg_kind(instructions, box, parameter_name)
                        }
                    }
                    skill_index = skill_index + 1
                }
            }
            (parameter_kind == "STRING") {
                @pointer_name = core.str.add("call_", name)
                pointer_name = core.str.add(pointer_name, "_arg_")
                pointer_name = core.str.add(pointer_name, core_num_text(index))
                pointer_name = core.str.add(pointer_name, "_ptr")
                text = core.str.add(text, "ptr %")
                text = core.str.add(text, pointer_name)
            }
            (parameter_kind == "NUMBER") {
                text = core.str.add(text, "i32 ")
                text = core.str.add(text, llvm_box_operand(argument))
            }
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
    @globals = llvm_box_string_globals(instructions)
    @declarations = "%Value = type { i32, i32, i64 }\n%Group = type { i32, [16 x %Value] }\n"
    declarations = core.str.add(declarations, llvm_box_types(instructions))
    declarations = core.str.add(declarations, "declare i32 @printf(ptr, ...)\ndeclare i32 @puts(ptr)\ndeclare i32 @system(ptr)\ndeclare ptr @malloc(i64)\ndeclare i64 @strlen(ptr)\ndeclare ptr @memcpy(ptr, ptr, i64)\ndeclare i32 @strcmp(ptr, ptr)\ndeclare i32 @isalpha(i32)\ndeclare i32 @isdigit(i32)\ndeclare i32 @isalnum(i32)\n")
    @functions = llvm_group_runtime()
    @main = ""
    @exit_value = "0"
    @names = []
    @values = []
    @box_names = []
    @box_types = []
    @string_names = []
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
                @skill_pass = llvm_skill_pass(skill_instruction)
                (skill_pass.found == yes) {
                    functions = core.str.add(functions, llvm_skill_pass_function(skill_instruction, skill_pass))
                }
                @skill_group_item = llvm_skill_group_item(skill_instruction)
                (skill_group_item.found == yes) {
                    functions = core.str.add(functions, llvm_skill_group_item_function(skill_instruction, skill_group_item))
                }
                @skill_scanner = llvm_skill_scanner(skill_instruction)
                (skill_scanner.found == yes) {
                    (skill_scanner.lexical == no) {
                        functions = core.str.add(functions, llvm_skill_scanner_function(instructions, skill_instruction, skill_scanner))
                    }
                    (skill_scanner.lexical == yes) {
                        functions = core.str.add(functions, llvm_skill_lex_function(instructions, skill_instruction, skill_scanner))
                    }
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
                    main = core.str.add(main, llvm_group_init(instructions, instruction.name, instruction.value, box_names, box_types))
                }
                (instruction.value.op == "BOX") {
                    main = core.str.add(main, llvm_box_init(instructions, instruction.name, instruction.value))
                    box_names = core.group.add(box_names, instruction.name)
                    box_types = core.group.add(box_types, instruction.value.name)
                }
                (instruction.value.op == "CALL") {
                    @call_arg_index = 0
                    @call_arg_count = core.group.count(instruction.value.args)
                    drum (call_arg_count) {
                        (call_arg_index < call_arg_count) {
                            @call_argument = core.group.item(instruction.value.args, call_arg_index)
                            (call_argument.op == "STRING") {
                                @call_global = core.str.add("call_", instruction.name)
                                call_global = core.str.add(call_global, "_arg_")
                                call_global = core.str.add(call_global, core_num_text(call_arg_index))
                                @call_pointer = core.str.add(call_global, "_ptr")
                                main = core.str.add(main, llvm_string_pointer(call_pointer, call_global, call_argument.value))
                            }
                            call_arg_index = call_arg_index + 1
                        }
                    }
                    (instruction.value.name == "core.group.add") {
                        main = core.str.add(main, llvm_group_add(instructions, instruction.name, instruction.value, box_names, box_types))
                    }
                    (instruction.value.name == "core.group.item") {
                        @static_item = llvm_group_item_static(instruction.value, names, values)
                        main = core.str.add(main, llvm_group_item_assign(instruction.name, instruction.value, static_item))
                        (static_item.op == "STRING") { string_names = core.group.add(string_names, instruction.name) }
                        (static_item.op == "PATH") {
                            @static_box_index = 0
                            @static_box_count = core.group.count(box_names)
                            drum (static_box_count) {
                                (static_box_index < static_box_count) {
                                    (core.group.item(box_names, static_box_index) == static_item.value) {
                                        box_names = core.group.add(box_names, instruction.name)
                                        box_types = core.group.add(box_types, core.group.item(box_types, static_box_index))
                                    }
                                    static_box_index = static_box_index + 1
                                }
                            }
                        }
                    }
                    @call_box = llvm_find_skill_box(instructions, instruction.value.name)
                    (call_box.found == yes) {
                        main = core.str.add(main, llvm_box_call(instructions, instruction.name, instruction.value, call_box.box))
                        box_names = core.group.add(box_names, instruction.name)
                        box_types = core.group.add(box_types, call_box.box.name)
                    }
                    @call_change = llvm_find_skill_box_change(instructions, instruction.value.name)
                    (call_change.found == yes) {
                        main = core.str.add(main, llvm_box_change_call(instructions, instruction.name, instruction.value, call_change))
                        box_names = core.group.add(box_names, instruction.name)
                        box_types = core.group.add(box_types, call_change.box)
                    }
                    @call_pass = llvm_find_skill_pass(instructions, instruction.value.name)
                    (call_pass.found == yes) {
                        @source = core.group.item(instruction.value.args, 0)
                        @source_box = ""
                        @has_source_box = no
                        @source_index = 0
                        @source_count = core.group.count(box_names)
                        drum (source_count) {
                            (source_index < source_count) {
                                (core.group.item(box_names, source_index) == source.value) {
                                    source_box = core.group.item(box_types, source_index)
                                    has_source_box = yes
                                }
                                source_index = source_index + 1
                            }
                        }
                        (has_source_box == yes) {
                            main = core.str.add(main, llvm_box_pass_call(instruction.name, instruction.value))
                            box_names = core.group.add(box_names, instruction.name)
                            box_types = core.group.add(box_types, source_box)
                        }
                    }
                    @call_group_item = llvm_find_skill_group_item(instructions, instruction.value.name)
                    (call_group_item.found == yes) {
                        @group_argument = core.group.item(instruction.value.args, 0)
                        @source_group = llvm_resolve(group_argument, names, values)
                        @item_box_type = llvm_group_box_type(source_group, box_names, box_types)
                        (item_box_type == "") {
                            (source_group.op == "CALL") {
                                @source_scanner = llvm_find_skill_scanner(instructions, source_group.name)
                                (source_scanner.found == yes) { item_box_type = llvm_box_for_field(instructions, "col") }
                            }
                        }
                        @item_type_id = llvm_box_type_id(instructions, item_box_type)
                        main = core.str.add(main, llvm_group_item_call(instruction.name, instruction.value, item_type_id))
                        (item_type_id > 0) {
                            box_names = core.group.add(box_names, instruction.name)
                            box_types = core.group.add(box_types, item_box_type)
                        }
                    }
                    @call_scanner = llvm_find_skill_scanner(instructions, instruction.value.name)
                    (call_scanner.found == yes) {
                        main = core.str.add(main, llvm_scanner_call(instruction.name, instruction.value))
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
                    main = core.str.add(main, "\n")
                    (field.kind == "STRING") {
                        @set_global = core.str.add("box_set_", id)
                        @set_pointer = core.str.add("box_set_string_", id)
                        main = core.str.add(main, llvm_string_pointer(set_pointer, set_global, instruction.value.value))
                        main = core.str.add(main, "  store ptr %")
                        main = core.str.add(main, set_pointer)
                        main = core.str.add(main, ", ptr %")
                        main = core.str.add(main, field_ptr)
                        main = core.str.add(main, "\n")
                    }
                    (field.kind == "NUMBER") {
                        main = core.str.add(main, "  store i32 ")
                        main = core.str.add(main, instruction.value.value)
                        main = core.str.add(main, ", ptr %")
                        main = core.str.add(main, field_ptr)
                        main = core.str.add(main, "\n")
                    }
                    (field.kind == "GROUP") {
                        @group_prefix = core.str.add("box_set_group_", id)
                        main = core.str.add(main, llvm_group_init_at(instructions, field_ptr, instruction.value, group_prefix, box_names, box_types))
                    }
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
                        @group_name = group_arg.value
                        (group_arg.op == "FIELD") {
                            @group_owner = group_arg.value
                            @group_box_name = ""
                            @group_box_index = 0
                            @group_box_count = core.group.count(box_names)
                            drum (group_box_count) {
                                (group_box_index < group_box_count) {
                                    (core.group.item(box_names, group_box_index) == group_owner.value) { group_box_name = core.group.item(box_types, group_box_index) }
                                    group_box_index = group_box_index + 1
                                }
                            }
                            @group_field = llvm_box_field(instructions, group_box_name, group_arg.name)
                            @group_field_id = core_num_text(group_field.index)
                            group_name = core.str.add("group_box_ptr_", id)
                            main = core.str.add(main, "  %")
                            main = core.str.add(main, group_name)
                            main = core.str.add(main, " = getelementptr %Box_")
                            main = core.str.add(main, group_box_name)
                            main = core.str.add(main, ", ptr %")
                            main = core.str.add(main, group_owner.value)
                            main = core.str.add(main, ", i32 0, i32 ")
                            main = core.str.add(main, group_field_id)
                            main = core.str.add(main, "\n")
                        }
                        @group_count_ptr = core.str.add("group_count_ptr_", id)
                        @group_count_value = core.str.add("group_count_", id)
                        main = core.str.add(main, "  %")
                        main = core.str.add(main, group_count_ptr)
                        main = core.str.add(main, " = getelementptr %Group, ptr %")
                        main = core.str.add(main, group_name)
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
                        @group_name = group_arg.value
                        (group_arg.op == "FIELD") {
                            @group_owner = group_arg.value
                            @group_box_name = ""
                            @group_box_index = 0
                            @group_box_count = core.group.count(box_names)
                            drum (group_box_count) {
                                (group_box_index < group_box_count) {
                                    (core.group.item(box_names, group_box_index) == group_owner.value) { group_box_name = core.group.item(box_types, group_box_index) }
                                    group_box_index = group_box_index + 1
                                }
                            }
                            @group_field = llvm_box_field(instructions, group_box_name, group_arg.name)
                            @group_field_id = core_num_text(group_field.index)
                            group_name = core.str.add("group_box_ptr_", id)
                            main = core.str.add(main, "  %")
                            main = core.str.add(main, group_name)
                            main = core.str.add(main, " = getelementptr %Box_")
                            main = core.str.add(main, group_box_name)
                            main = core.str.add(main, ", ptr %")
                            main = core.str.add(main, group_owner.value)
                            main = core.str.add(main, ", i32 0, i32 ")
                            main = core.str.add(main, group_field_id)
                            main = core.str.add(main, "\n")
                        }
                        @group_item_ptr = core.str.add("group_item_ptr_", id)
                        @group_item_value = core.str.add("group_item_", id)
                        main = core.str.add(main, "  %")
                        main = core.str.add(main, group_item_ptr)
                        main = core.str.add(main, " = getelementptr %Group, ptr %")
                        main = core.str.add(main, group_name)
                        main = core.str.add(main, ", i32 0, i32 1, i32 ")
                        main = core.str.add(main, index_arg.value)
                        @group_item_data_ptr = core.str.add("group_item_data_ptr_", id)
                        @group_item_raw = core.str.add("group_item_raw_", id)
                        main = core.str.add(main, "\n  %")
                        main = core.str.add(main, group_item_data_ptr)
                        main = core.str.add(main, " = getelementptr %Value, ptr %")
                        main = core.str.add(main, group_item_ptr)
                        main = core.str.add(main, ", i32 0, i32 2\n  %")
                        main = core.str.add(main, group_item_raw)
                        main = core.str.add(main, " = load i64, ptr %")
                        main = core.str.add(main, group_item_data_ptr)
                        main = core.str.add(main, "\n  %")
                        main = core.str.add(main, group_item_value)
                        main = core.str.add(main, " = trunc i64 %")
                        main = core.str.add(main, group_item_raw)
                        main = core.str.add(main, " to i32")
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
                        (field.kind == "NUMBER") {
                            main = core.str.add(main, "\n  %")
                            main = core.str.add(main, field_value)
                            main = core.str.add(main, " = load i32, ptr %")
                            main = core.str.add(main, field_ptr)
                            main = core.str.add(main, "\n")
                            exit_value = core.str.add("%", field_value)
                        }
                    }
                }
            }

            (instruction.op == "WRITE") {
                @source_argument = core.group.item(instruction.args, 0)
                @argument = llvm_resolve(source_argument, names, values)
                @native_string = no
                (source_argument.op == "PATH") {
                    @string_index = 0
                    @string_count = core.group.count(string_names)
                    drum (string_count) {
                        (string_index < string_count) {
                            (core.group.item(string_names, string_index) == source_argument.value) { native_string = yes }
                            string_index = string_index + 1
                        }
                    }
                }
                (native_string == yes) {
                    main = core.str.add(main, "  call i32 @puts(ptr %")
                    main = core.str.add(main, source_argument.value)
                    main = core.str.add(main, ")\n")
                }

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
                    (native_string == no) {
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

                (argument.op == "FIELD") {
                    @owner = argument.value
                    @box_name = ""
                    @box_index = 0
                    @box_count = core.group.count(box_names)
                    drum (box_count) {
                        (box_index < box_count) {
                            (core.group.item(box_names, box_index) == owner.value) { box_name = core.group.item(box_types, box_index) }
                            box_index = box_index + 1
                        }
                    }
                    @field = llvm_box_field(instructions, box_name, argument.name)
                    (field.found == yes) {
                        @field_id = core_num_text(field.index)
                        @field_ptr = core.str.add("write_field_ptr_", id)
                        @field_value = core.str.add("write_field_", id)
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
                        (field.kind == "STRING") { main = core.str.add(main, " = load ptr, ptr %") }
                        (field.kind == "NUMBER") { main = core.str.add(main, " = load i32, ptr %") }
                        main = core.str.add(main, field_ptr)
                        main = core.str.add(main, "\n")
                        (field.kind == "STRING") {
                            main = core.str.add(main, "  call i32 @puts(ptr %")
                            main = core.str.add(main, field_value)
                            main = core.str.add(main, ")\n")
                        }
                    }
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
