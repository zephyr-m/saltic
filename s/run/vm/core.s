use core

Op = enum {
    NOP,
    PUSH,
    ADD,
    SUB,
    MUL,
    DIV,
    STORE,
    LOAD,
    POP,
    GROUP,
    BOX_NEW,
    FIELD,
    IF,
    DRUM,
    SWITCH,
    RESCUE,
    EQ,
    GT,
    LT,
    CALL,
    RETURN,
}

PayloadKind = enum {
    NONE,
    NUMBER,
    TEXT,
    ERROR,
    ENUM,
}

CallKind = enum {
    LOCAL,
    BOUNDARY,
}

Instr = Box {
    op = Op.NOP
    target = ""
    argc = 0
    call_kind = CallKind.LOCAL
    payload_kind = PayloadKind.NONE
    number_value = 0
    text_value = ""
    error_name = ""
    enum_name = ""
    variant_name = ""
    field_a = ""
    field_b = ""
    body = none
}

TinyError = Box {
    kind = "error"
    name = ""
}

TinyEnum = Box {
    kind = "enum"
    enum_name = ""
    variant_name = ""
}

Binding = Box {
    name = ""
    value = none
}

TinyGroup = Box {
    first = none
    second = none
    count = 0
}

TinyBox = Box {
    name = ""
    first = Binding {}
    second = Binding {}
    count = 0
}

TinyBody = Box {
    first = Instr {}
    second = Instr {}
    third = Instr {}
    fourth = Instr {}
    count = 0
}

TinyCase = Box {
    tag = ""
    body = TinyBody {}
}

TinySwitch = Box {
    first = TinyCase {}
    second = TinyCase {}
    count = 0
}

TinyFunction = Box {
    name = ""
    param_a = ""
    param_b = ""
    argc = 0
    body = TinyBody {}
}

TinyProgram = Box {
    first = TinyFunction {}
    second = TinyFunction {}
    count = 0
}

BoundaryHandler = Box {
    name = ""
}

BoundaryTable = Box {
    handlers = []
}

skill instr_nop() {
    out Instr {}
}

skill instr_push_number(value) {
    out Instr {
        op = Op.PUSH
        payload_kind = PayloadKind.NUMBER
        number_value = value
    }
}

skill instr_push_text(value) {
    out Instr {
        op = Op.PUSH
        payload_kind = PayloadKind.TEXT
        text_value = value
    }
}

skill instr_push_none() {
    out Instr {
        op = Op.PUSH
        payload_kind = PayloadKind.NONE
    }
}

skill instr_push_error(name) {
    out Instr {
        op = Op.PUSH
        payload_kind = PayloadKind.ERROR
        error_name = name
    }
}

skill instr_push_enum(enum_name, variant_name) {
    out Instr {
        op = Op.PUSH
        payload_kind = PayloadKind.ENUM
        enum_name = enum_name
        variant_name = variant_name
    }
}

skill instr_add() {
    out Instr { op = Op.ADD }
}

skill instr_sub() {
    out Instr { op = Op.SUB }
}

skill instr_mul() {
    out Instr { op = Op.MUL }
}

skill instr_div() {
    out Instr { op = Op.DIV }
}

skill instr_eq() {
    out Instr { op = Op.EQ }
}

skill instr_gt() {
    out Instr { op = Op.GT }
}

skill instr_lt() {
    out Instr { op = Op.LT }
}

skill instr_store(name) {
    out Instr {
        op = Op.STORE
        target = name
    }
}

skill instr_load(name) {
    out Instr {
        op = Op.LOAD
        target = name
    }
}

skill instr_pop() {
    out Instr { op = Op.POP }
}

skill instr_group(count) {
    out Instr {
        op = Op.GROUP
        argc = count
    }
}

skill instr_box_new(name, field_a, field_b, count) {
    out Instr {
        op = Op.BOX_NEW
        target = name
        field_a = field_a
        field_b = field_b
        argc = count
    }
}

skill instr_field(name) {
    out Instr {
        op = Op.FIELD
        target = name
    }
}

skill body_one(first) {
    out TinyBody {
        first = first
        count = 1
    }
}

skill body_two(first, second) {
    out TinyBody {
        first = first
        second = second
        count = 2
    }
}

skill body_four(first, second, third, fourth) {
    out TinyBody {
        first = first
        second = second
        third = third
        fourth = fourth
        count = 4
    }
}

skill instr_if(body) {
    out Instr {
        op = Op.IF
        body = body
    }
}

skill instr_drum(body) {
    out Instr {
        op = Op.DRUM
        body = body
    }
}

skill switch_case(tag, body) {
    out TinyCase {
        tag = tag
        body = body
    }
}

skill switch_one(first) {
    out TinySwitch {
        first = first
        count = 1
    }
}

skill switch_two(first, second) {
    out TinySwitch {
        first = first
        second = second
        count = 2
    }
}

skill instr_switch(cases) {
    out Instr {
        op = Op.SWITCH
        body = cases
    }
}

skill instr_rescue(err, body) {
    out Instr {
        op = Op.RESCUE
        target = err
        body = body
    }
}

skill instr_call(name, argc) {
    out instr_call_local(name, argc)
}

skill instr_call_local(name, argc) {
    out Instr {
        op = Op.CALL
        target = name
        argc = argc
        call_kind = CallKind.LOCAL
    }
}

skill instr_call_boundary(name, argc) {
    out Instr {
        op = Op.CALL
        target = name
        argc = argc
        call_kind = CallKind.BOUNDARY
    }
}

skill instr_return() {
    out Instr { op = Op.RETURN }
}

skill tiny_function(name, param_a, param_b, argc, body) {
    out TinyFunction {
        name = name
        param_a = param_a
        param_b = param_b
        argc = argc
        body = body
    }
}

skill tiny_program_one(first) {
    out TinyProgram {
        first = first
        count = 1
    }
}

skill tiny_program_two(first, second) {
    out TinyProgram {
        first = first
        second = second
        count = 2
    }
}

skill boundary_handler(name) {
    out BoundaryHandler {
        name = name
    }
}

skill boundary_table(handlers) {
    out BoundaryTable {
        handlers = handlers
    }
}

skill core_boundary_table() {
    @println = boundary_handler("core.io.println")
    @group_count = boundary_handler("core.group.count")
    @group_at = boundary_handler("core.group.at")
    @visual_trace_text = boundary_handler("visual.trace_text")
    @world_trace_text = boundary_handler("world.trace_text")
    out boundary_table([
        println,
        group_count,
        group_at,
        visual_trace_text,
        world_trace_text,
    ])
}

Env = Box {
    first = Binding {}
    second = Binding {}
    third = Binding {}
    fourth = Binding {}
    count = 0
}

Stack = Box {
    a = 0
    b = 0
    sp = 0
}

Frame = Box {
    stack = Stack {}
    env = Env {}
    pc = 0
    result = 0
    returned = no
    functions = TinyProgram {}
    boundaries = BoundaryTable {}
}

skill env_load(env, name) {
    (env.first.name == name) {
        out env.first.value
    }
    (env.second.name == name) {
        out env.second.value
    }
    (env.third.name == name) {
        out env.third.value
    }
    (env.fourth.name == name) {
        out env.fourth.value
    }
    out 0
}

skill env_store(env, name, value) {
    (env.first.name == name) {
        out Env {
            first = Binding { name = name value = value }
            second = env.second
            third = env.third
            fourth = env.fourth
            count = env.count
        }
    }
    (env.second.name == name) {
        out Env {
            first = env.first
            second = Binding { name = name value = value }
            third = env.third
            fourth = env.fourth
            count = env.count
        }
    }
    (env.third.name == name) {
        out Env {
            first = env.first
            second = env.second
            third = Binding { name = name value = value }
            fourth = env.fourth
            count = env.count
        }
    }
    (env.fourth.name == name) {
        out Env {
            first = env.first
            second = env.second
            third = env.third
            fourth = Binding { name = name value = value }
            count = env.count
        }
    }
    (env.count == 0) {
        out Env {
            first = Binding { name = name value = value }
            second = env.second
            third = env.third
            fourth = env.fourth
            count = 1
        }
    }
    (env.count == 1) {
        out Env {
            first = env.first
            second = Binding { name = name value = value }
            third = env.third
            fourth = env.fourth
            count = 2
        }
    }
    (env.count == 2) {
        out Env {
            first = env.first
            second = env.second
            third = Binding { name = name value = value }
            fourth = env.fourth
            count = 3
        }
    }
    (env.count == 3) {
        out Env {
            first = env.first
            second = env.second
            third = env.third
            fourth = Binding { name = name value = value }
            count = 4
        }
    }
    out env
}

skill stack_push(stack, value) {
    (stack.sp == 0) {
        out Stack {
            a = value
            b = stack.b
            sp = 1
        }
    }
    (stack.sp == 1) {
        out Stack {
            a = stack.a
            b = value
            sp = 2
        }
    }
    out stack
}

skill stack_pop(stack) {
    (stack.sp == 2) {
        out Stack {
            a = stack.a
            b = stack.b
            sp = 1
        }
    }
    (stack.sp == 1) {
        out Stack {
            a = stack.a
            b = stack.b
            sp = 0
        }
    }
    out stack
}

skill stack_top(stack) {
    (stack.sp == 2) {
        out stack.b
    }
    (stack.sp == 1) {
        out stack.a
    }
    out 0
}

skill stack_second(stack) {
    (stack.sp == 2) {
        out stack.a
    }
    out 0
}

skill stack_group(stack, count) {
    (count == 0) {
        out stack_push(stack, TinyGroup { count = 0 })
    }
    (count == 1) {
        @first = stack_top(stack)
        @without_first = stack_pop(stack)
        out stack_push(without_first, TinyGroup {
            first = first
            count = 1
        })
    }
    (count == 2) {
        @second = stack_top(stack)
        @without_second = stack_pop(stack)
        @first = stack_top(without_second)
        @without_first = stack_pop(without_second)
        out stack_push(without_first, TinyGroup {
            first = first
            second = second
            count = 2
        })
    }
    out stack
}

skill stack_box_new(stack, name, field_a, field_b, count) {
    (count == 0) {
        out stack_push(stack, TinyBox {
            name = name
            count = 0
        })
    }
    (count == 1) {
        @first = stack_top(stack)
        @without_first = stack_pop(stack)
        out stack_push(without_first, TinyBox {
            name = name
            first = Binding { name = field_a value = first }
            count = 1
        })
    }
    (count == 2) {
        @second = stack_top(stack)
        @without_second = stack_pop(stack)
        @first = stack_top(without_second)
        @without_first = stack_pop(without_second)
        out stack_push(without_first, TinyBox {
            name = name
            first = Binding { name = field_a value = first }
            second = Binding { name = field_b value = second }
            count = 2
        })
    }
    out stack
}

skill tiny_box_field(box, name) {
    (box.first.name == name) {
        out box.first.value
    }
    (box.second.name == name) {
        out box.second.value
    }
    out TinyError { name = "UnknownField" }
}

skill stack_field(stack, name) {
    @box = stack_top(stack)
    @without_box = stack_pop(stack)
    out stack_push(without_box, tiny_box_field(box, name))
}

skill stack_binary_add(stack) {
    @right = stack_top(stack)
    @without_right = stack_pop(stack)
    @left = stack_top(without_right)
    @without_left = stack_pop(without_right)
    out stack_push(without_left, left + right)
}

skill stack_binary_sub(stack) {
    @right = stack_top(stack)
    @without_right = stack_pop(stack)
    @left = stack_top(without_right)
    @without_left = stack_pop(without_right)
    out stack_push(without_left, left - right)
}

skill stack_binary_mul(stack) {
    @right = stack_top(stack)
    @without_right = stack_pop(stack)
    @left = stack_top(without_right)
    @without_left = stack_pop(without_right)
    out stack_push(without_left, left * right)
}

skill stack_binary_div(stack) {
    @right = stack_top(stack)
    @without_right = stack_pop(stack)
    @left = stack_top(without_right)
    @without_left = stack_pop(without_right)
    (right == 0) {
        out stack_push(without_left, TinyError { name = "DivisionByZero" })
    }
    out stack_push(without_left, left / right)
}

skill stack_binary_eq(stack) {
    @right = stack_top(stack)
    @without_right = stack_pop(stack)
    @left = stack_top(without_right)
    @without_left = stack_pop(without_right)
    out stack_push(without_left, left == right)
}

skill stack_binary_gt(stack) {
    @right = stack_top(stack)
    @without_right = stack_pop(stack)
    @left = stack_top(without_right)
    @without_left = stack_pop(without_right)
    out stack_push(without_left, left > right)
}

skill stack_binary_lt(stack) {
    @right = stack_top(stack)
    @without_right = stack_pop(stack)
    @left = stack_top(without_right)
    @without_left = stack_pop(without_right)
    out stack_push(without_left, left < right)
}

skill frame_with(frame, stack, env, result, returned) {
    out Frame {
        stack = stack
        env = env
        pc = frame.pc + 1
        result = result
        returned = returned
        functions = frame.functions
        boundaries = frame.boundaries
    }
}

skill run_tiny_body(frame, body) {
    @next = frame
    (body.count > 0) {
        next = step_tiny(next, body.first)
    }
    (body.count > 1) {
        next = step_tiny(next, body.second)
    }
    (body.count > 2) {
        next = step_tiny(next, body.third)
    }
    (body.count > 3) {
        next = step_tiny(next, body.fourth)
    }
    out next
}

skill run_tiny_body_count(frame, body, count) {
    @next = frame
    (count > 0) {
        next = run_tiny_body(next, body)
    }
    (count > 1) {
        next = run_tiny_body(next, body)
    }
    (count > 2) {
        next = run_tiny_body(next, body)
    }
    (count > 3) {
        next = run_tiny_body(next, body)
    }
    out next
}

skill tiny_case_matches(value, tag) {
    (value.kind == "enum") {
        (value.variant_name == tag) {
            out yes
        }
    }
    (value.kind == "error") {
        (value.name == tag) {
            out yes
        }
    }
    out no
}

skill run_tiny_switch(frame, value, cases) {
    @next = frame
    @matched = no

    (cases.count > 0) {
        (tiny_case_matches(value, cases.first.tag) == yes) {
            next = run_tiny_body(next, cases.first.body)
            matched = yes
        }
    }
    (matched == no) {
        (cases.count > 1) {
            (tiny_case_matches(value, cases.second.tag) == yes) {
                next = run_tiny_body(next, cases.second.body)
                matched = yes
            }
        }
    }
    (matched == no) {
        next = Frame {
            stack = stack_push(next.stack, none)
            env = next.env
            pc = next.pc
            result = next.result
            returned = next.returned
            functions = next.functions
        }
    }

    out next
}

skill tiny_function_find(functions, name) {
    (functions.count > 0) {
        (functions.first.name == name) {
            out functions.first
        }
    }
    (functions.count > 1) {
        (functions.second.name == name) {
            out functions.second
        }
    }
    out TinyFunction {
        name = "__missing__"
    }
}

skill tiny_call_env(fn, arg_a, arg_b) {
    @env = Env {}
    (fn.argc > 0) {
        env = env_store(env, fn.param_a, arg_a)
    }
    (fn.argc > 1) {
        env = env_store(env, fn.param_b, arg_b)
    }
    out env
}

skill boundary_find(boundaries, name) {
    @index = 0
    @found = BoundaryHandler {
        name = "__missing__"
    }

    drum (core.group.count(boundaries.handlers)) {
        (found.name == "__missing__") {
            @handler = core.group.at(boundaries.handlers, index)
            (handler.name == name) {
                found = handler
            }
        }
        index = index + 1
    }

    out found
}

skill stack_call_boundary(stack, boundaries, name, argc) {
    @handler = boundary_find(boundaries, name)

    (handler.name == "core.io.println") {
        (argc == 2) {
            @left = stack_second(stack)
            @right = stack_top(stack)
            core.io.println(left, right)
            @without_right = stack_pop(stack)
            @without_left = stack_pop(without_right)
            out stack_push(without_left, 0)
        }
    }

    (handler.name == "core.group.count") {
        (argc == 1) {
            @group = stack_top(stack)
            @without_group = stack_pop(stack)
            out stack_push(without_group, group.count)
        }
    }

    (handler.name == "core.group.at") {
        (argc == 2) {
            @index = stack_top(stack)
            @without_index = stack_pop(stack)
            @group = stack_top(without_index)
            @without_group = stack_pop(without_index)
            (index == 0) {
                out stack_push(without_group, group.first)
            }
            (index == 1) {
                out stack_push(without_group, group.second)
            }
            out stack_push(without_group, TinyError { name = "IndexOutOfRange" })
        }
    }

    (handler.name == "visual.trace_text") {
        (argc == 0) {
            out stack_push(stack, visual.trace_text())
        }
    }

    (handler.name == "world.trace_text") {
        (argc == 0) {
            out stack_push(stack, world.trace_text())
        }
    }

    out stack_push(stack, TinyError { name = "UnknownBoundary" })
}

skill stack_call_tiny_function(stack, functions, boundaries, name, argc) {
    @arg_a = none
    @arg_b = none
    @without_args = stack

    (argc == 1) {
        arg_a = stack_top(stack)
        without_args = stack_pop(stack)
    }
    (argc == 2) {
        arg_b = stack_top(stack)
        @without_b = stack_pop(stack)
        arg_a = stack_top(without_b)
        without_args = stack_pop(without_b)
    }

    @fn = tiny_function_find(functions, name)
    @call_frame = Frame {
        stack = Stack {}
        env = tiny_call_env(fn, arg_a, arg_b)
        functions = functions
        boundaries = boundaries
    }
    @after_call = run_tiny_body(call_frame, fn.body)
    out stack_push(without_args, after_call.result)
}

skill step_tiny(frame, instr) {
    (frame.returned == yes) {
        out frame
    }

    @stack = frame.stack
    @env = frame.env
    @result = frame.result
    @returned = frame.returned

    (instr.op == Op.PUSH) {
        (instr.payload_kind == PayloadKind.NONE) {
            stack = stack_push(stack, none)
        }
        (instr.payload_kind == PayloadKind.NUMBER) {
            stack = stack_push(stack, instr.number_value)
        }
        (instr.payload_kind == PayloadKind.TEXT) {
            stack = stack_push(stack, instr.text_value)
        }
        (instr.payload_kind == PayloadKind.ERROR) {
            stack = stack_push(stack, TinyError { name = instr.error_name })
        }
        (instr.payload_kind == PayloadKind.ENUM) {
            stack = stack_push(stack, TinyEnum {
                enum_name = instr.enum_name
                variant_name = instr.variant_name
            })
        }
    }

    (instr.op == Op.STORE) {
        @value = stack_top(stack)
        env = env_store(env, instr.target, value)
        stack = stack_pop(stack)
    }

    (instr.op == Op.LOAD) {
        @loaded = env_load(env, instr.target)
        stack = stack_push(stack, loaded)
    }

    (instr.op == Op.POP) {
        stack = stack_pop(stack)
    }

    (instr.op == Op.GROUP) {
        stack = stack_group(stack, instr.argc)
    }

    (instr.op == Op.BOX_NEW) {
        stack = stack_box_new(stack, instr.target, instr.field_a, instr.field_b, instr.argc)
    }

    (instr.op == Op.FIELD) {
        stack = stack_field(stack, instr.target)
    }

    (instr.op == Op.IF) {
        @test = stack_top(stack)
        stack = stack_pop(stack)
        (test == yes) {
            @body_frame = Frame {
                stack = stack
                env = env
                pc = frame.pc
                result = result
                returned = returned
                functions = frame.functions
                boundaries = frame.boundaries
            }
            @after_body = run_tiny_body(body_frame, instr.body)
            stack = after_body.stack
            env = after_body.env
            result = after_body.result
            returned = after_body.returned
        }
    }

    (instr.op == Op.DRUM) {
        @count = stack_top(stack)
        stack = stack_pop(stack)
        @body_frame = Frame {
            stack = stack
            env = env
            pc = frame.pc
            result = result
            returned = returned
            functions = frame.functions
            boundaries = frame.boundaries
        }
        @after_body = run_tiny_body_count(body_frame, instr.body, count)
        stack = after_body.stack
        env = after_body.env
        result = after_body.result
        returned = after_body.returned
    }

    (instr.op == Op.SWITCH) {
        @value = stack_top(stack)
        stack = stack_pop(stack)
        @body_frame = Frame {
            stack = stack
            env = env
            pc = frame.pc
            result = result
            returned = returned
            functions = frame.functions
            boundaries = frame.boundaries
        }
        @after_body = run_tiny_switch(body_frame, value, instr.body)
        stack = after_body.stack
        env = after_body.env
        result = after_body.result
        returned = after_body.returned
    }

    (instr.op == Op.RESCUE) {
        @value = stack_top(stack)
        stack = stack_pop(stack)
        (value.kind == "error") {
            env = env_store(env, instr.target, value)
            @body_frame = Frame {
                stack = stack
                env = env
                pc = frame.pc
                result = result
                returned = returned
                functions = frame.functions
                boundaries = frame.boundaries
            }
            @after_body = run_tiny_body(body_frame, instr.body)
            stack = after_body.stack
            env = after_body.env
            result = after_body.result
            returned = after_body.returned
        }
        (value.kind == "enum") {
            stack = stack_push(stack, value)
        }
    }

    (instr.op == Op.ADD) {
        stack = stack_binary_add(stack)
    }

    (instr.op == Op.SUB) {
        stack = stack_binary_sub(stack)
    }

    (instr.op == Op.MUL) {
        stack = stack_binary_mul(stack)
    }

    (instr.op == Op.DIV) {
        stack = stack_binary_div(stack)
    }

    (instr.op == Op.EQ) {
        stack = stack_binary_eq(stack)
    }

    (instr.op == Op.GT) {
        stack = stack_binary_gt(stack)
    }

    (instr.op == Op.LT) {
        stack = stack_binary_lt(stack)
    }

    (instr.op == Op.CALL) {
        (instr.call_kind == CallKind.BOUNDARY) {
            stack = stack_call_boundary(stack, frame.boundaries, instr.target, instr.argc)
        }
        (instr.call_kind == CallKind.LOCAL) {
            (frame.functions.count > 0) {
                (instr.target == frame.functions.first.name) {
                    stack = stack_call_tiny_function(stack, frame.functions, frame.boundaries, instr.target, instr.argc)
                }
            }
            (frame.functions.count > 1) {
                (instr.target == frame.functions.second.name) {
                    stack = stack_call_tiny_function(stack, frame.functions, frame.boundaries, instr.target, instr.argc)
                }
            }
        }
    }

    (instr.op == Op.RETURN) {
        result = stack_top(stack)
        returned = yes
    }

    out frame_with(frame, stack, env, result, returned)
}

skill run_tiny(bytecode) {
    @frame = Frame {
        boundaries = core_boundary_table()
    }

    drum (core.group.count(bytecode)) {
        (frame.returned == no) {
            @instr = core.group.at(bytecode, frame.pc)
            frame = step_tiny(frame, instr)
        }
    }

    out frame.result
}

skill run_tiny_with_functions(bytecode, functions) {
    @frame = Frame {
        functions = functions
        boundaries = core_boundary_table()
    }

    drum (core.group.count(bytecode)) {
        (frame.returned == no) {
            @instr = core.group.at(bytecode, frame.pc)
            frame = step_tiny(frame, instr)
        }
    }

    out frame.result
}
