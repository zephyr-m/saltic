use core
use tiny_vm.core

program() {
    @add_body = body_four(instr_load("a"), instr_load("b"), instr_add(), instr_return())
    @add_fn = tiny_function("add_two", "a", "b", 2, add_body)
    @functions = tiny_program_one(add_fn)

    @bytecode = [
        instr_push_number(20),
        instr_push_number(22),
        instr_call_local("add_two", 2),
        instr_push_number(42),
        instr_eq(),
        instr_return(),
    ]

    @result = run_tiny_with_functions(bytecode, functions)
    core.io.println("step-call result=", result)
    out result
}
