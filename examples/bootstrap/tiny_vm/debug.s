use core
use core

skill op_text(op) {
    (op == Op.NOP) {
        out "nop"
    }
    (op == Op.PUSH) {
        out "push"
    }
    (op == Op.ADD) {
        out "add"
    }
    (op == Op.SUB) {
        out "sub"
    }
    (op == Op.MUL) {
        out "mul"
    }
    (op == Op.DIV) {
        out "div"
    }
    (op == Op.STORE) {
        out "store"
    }
    (op == Op.LOAD) {
        out "load"
    }
    (op == Op.POP) {
        out "pop"
    }
    (op == Op.GROUP) {
        out "group"
    }
    (op == Op.BOX_NEW) {
        out "box-new"
    }
    (op == Op.FIELD) {
        out "field"
    }
    (op == Op.IF) {
        out "if"
    }
    (op == Op.DRUM) {
        out "drum"
    }
    (op == Op.SWITCH) {
        out "switch"
    }
    (op == Op.RESCUE) {
        out "rescue"
    }
    (op == Op.EQ) {
        out "eq"
    }
    (op == Op.GT) {
        out "gt"
    }
    (op == Op.LT) {
        out "lt"
    }
    (op == Op.CALL) {
        out "call"
    }
    (op == Op.RETURN) {
        out "return"
    }
    out "unknown"
}

skill trace_stack(stack) {
    (stack.sp == 0) {
        core.io.println("  stack=[]")
    }
    (stack.sp == 1) {
        core.io.println("  stack=[", stack.a, "]")
    }
    (stack.sp == 2) {
        core.io.println("  stack=[", stack.a, ", ", stack.b, "]")
    }
}

skill trace_env(env) {
    core.io.println("  env.count=", env.count)
    (env.count > 0) {
        core.io.println("  env.", env.first.name, "=", env.first.value)
    }
    (env.count > 1) {
        core.io.println("  env.", env.second.name, "=", env.second.value)
    }
    (env.count > 2) {
        core.io.println("  env.", env.third.name, "=", env.third.value)
    }
    (env.count > 3) {
        core.io.println("  env.", env.fourth.name, "=", env.fourth.value)
    }
}

skill trace_frame(frame, instr) {
    core.io.println("pc=", frame.pc, " op=", op_text(instr.op))
    trace_stack(frame.stack)
    trace_env(frame.env)
}

skill run_tiny_traced(bytecode) {
    @frame = Frame {}

    drum (core.group.count(bytecode)) {
        (frame.returned == no) {
            @instr = core.group.at(bytecode, frame.pc)
            trace_frame(frame, instr)
            frame = step_tiny(frame, instr)
            core.io.println("  =>")
            trace_stack(frame.stack)
            trace_env(frame.env)
        }
    }

    out frame.result
}
