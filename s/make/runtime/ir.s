use core
use s.run.core.num
use s.make.runtime.registry
use s.make.compiler.semantics.scope
use s.run.runtime.syscall

RuntimeOut = Box {
    ok = yes
    value = none
    steps = 0
    diagnostics = []
}

skill runtime_value(value, scope, registry) {
    (value.op == "NUMBER") {
        out runtime_number(value.value)
    }
    (value.op == "CALL") {
        out runtime_call(value, scope, registry)
    }
    (value.op == "PATH") {
        @resolved = scope_get(scope, value.value)
        out resolved.value
    }
    out value.value
}

skill runtime_call(call, scope, registry) {
    @lookup = runtime_skill(registry, call.name)
    (lookup.builtin == "core.num.add") { out runtime_core_num(call, scope, registry, "add") }
    (lookup.builtin == "core.num.sub") { out runtime_core_num(call, scope, registry, "sub") }
    (lookup.builtin == "core.num.mul") { out runtime_core_num(call, scope, registry, "mul") }
    (lookup.builtin == "core.num.div") { out runtime_core_num(call, scope, registry, "div") }
    (lookup.builtin == "core.num.text") { out runtime_core_num_text(call, scope, registry) }
    out runtime_call_skill(call, scope, registry)
}

skill runtime_number(text) {
    @index = 0
    @result = 0
    @length = core.str.len(text)
    drum (length) {
        (index < length) {
            @ch = core.str.at(text, index)
            @digit = 0
            (ch == "1") { digit = 1 }
            (ch == "2") { digit = 2 }
            (ch == "3") { digit = 3 }
            (ch == "4") { digit = 4 }
            (ch == "5") { digit = 5 }
            (ch == "6") { digit = 6 }
            (ch == "7") { digit = 7 }
            (ch == "8") { digit = 8 }
            (ch == "9") { digit = 9 }
            result = result * 10 + digit
            index = index + 1
        }
    }
    out result
}

skill runtime_core_num(call, scope, registry, operation) {
    @left_arg = core.group.item(call.args, 0)
    @right_arg = core.group.item(call.args, 1)
    @left = runtime_value(left_arg, scope, registry)
    @right = runtime_value(right_arg, scope, registry)
    (operation == "add") { out core_num_add(left, right) }
    (operation == "sub") { out core_num_sub(left, right) }
    (operation == "mul") { out core_num_mul(left, right) }
    (operation == "div") { out core_num_div(left, right) }
    out none
}

skill runtime_core_num_text(call, scope, registry) {
    @value = runtime_value(core.group.item(call.args, 0), scope, registry)
    out core_num_text(value)
}

skill runtime_skill(registry, name) {
    out runtime_registry_find(registry, name)
}

skill runtime_call_skill(call, parent_scope, registry) {
    @lookup = runtime_skill(registry, call.name)
    (lookup.found == no) {
        out none
    }
    @decl = lookup.value
    @local_scope = scope_child(parent_scope)
    @arg_index = 0
    @arg_count = core.group.count(call.args)
    drum (arg_count) {
        (arg_index < arg_count) {
            @arg = core.group.item(call.args, arg_index)
            @arg_value = runtime_value(arg, parent_scope, registry)
            local_scope = scope_put(local_scope, core.group.item(decl.args, arg_index), arg_value)
            arg_index = arg_index + 1
        }
    }
    @result = none
    @body_index = 0
    @body_count = core.group.count(decl.body)
    drum (body_count) {
        (body_index < body_count) {
            @instruction = core.group.item(decl.body, body_index)
            (instruction.op == "OUT") {
                result = runtime_value(instruction.value, local_scope, registry)
            }
            (instruction.op == "ASSIGN") {
                @assigned = runtime_value(instruction.value, local_scope, registry)
                local_scope = scope_put(local_scope, instruction.name, assigned)
            }
            body_index = body_index + 1
        }
    }
    out result
}

skill runtime_ir_run(instructions) {
    @registry = runtime_registry_start()
    @scope = scope_start()
    @result = none
    @index = 0
    @steps = 0
    @count = core.group.count(instructions)
    drum (count) {
        (index < count) {
            @instruction = core.group.item(instructions, index)
            (instruction.op == "SKILL") {
                registry = runtime_registry_add(registry, instruction)
            }
            (instruction.op == "ASSIGN") {
                @assigned = runtime_value(instruction.value, scope, registry)
                scope = scope_put(scope, instruction.name, assigned)
            }
            (instruction.op == "OUT") {
                result = runtime_value(instruction.value, scope, registry)
            }
            (instruction.op == "WRITE") {
                @write_arg = core.group.item(instruction.args, 0)
                @write_value = runtime_value(write_arg, scope, registry)
                @write_syscall = syscall_write(1, write_value)
                core.io.show(write_value)
            }
            steps = steps + 1
            index = index + 1
        }
    }
    out RuntimeOut {
        ok = yes
        value = result
        steps = steps
        diagnostics = []
    }
}
