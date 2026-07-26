use core
use s.run.vm.core

program() {
    visual.sheet("boundary")
    visual.present()
    @box = world.spawn("box")
    world.emit(box, "place", 1, 2)
    world.step()

    @add_body = body_four(instr_load("a"), instr_load("b"), instr_add(), instr_return())
    @add_fn = tiny_function("add_two", "a", "b", 2, add_body)
    @functions = tiny_program_one(add_fn)

    @bytecode = [
        instr_push_number(20),
        instr_push_number(22),
        instr_call_local("add_two", 2),
        instr_store("result"),
        instr_push_text("boundary result="),
        instr_load("result"),
        instr_call_boundary("core.io.println", 2),
        instr_pop(),
        instr_push_text("alpha"),
        instr_push_text("beta"),
        instr_group(2),
        instr_store("items"),
        instr_load("items"),
        instr_call_boundary("core.group.count", 1),
        instr_store("count"),
        instr_push_text("boundary count="),
        instr_load("count"),
        instr_call_boundary("core.io.println", 2),
        instr_pop(),
        instr_load("items"),
        instr_push_number(1),
        instr_call_boundary("core.group.at", 2),
        instr_store("picked"),
        instr_push_text("boundary picked="),
        instr_load("picked"),
        instr_call_boundary("core.io.println", 2),
        instr_pop(),
        instr_push_text("boundary visual="),
        instr_call_boundary("visual.trace_text", 0),
        instr_call_boundary("core.io.println", 2),
        instr_pop(),
        instr_push_text("boundary world="),
        instr_call_boundary("world.trace_text", 0),
        instr_call_boundary("core.io.println", 2),
        instr_pop(),
        instr_load("result"),
        instr_push_number(42),
        instr_eq(),
        instr_return(),
    ]

    @result = run_tiny_with_functions(bytecode, functions)
    core.io.println("step-boundary result=", result)
    out result
}
