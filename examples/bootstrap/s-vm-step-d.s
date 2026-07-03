use core
use tiny_vm.core

program() {
    @then_body = body_two(instr_push_number(41), instr_store("value"))

    @bytecode = [
        instr_push_number(1),
        instr_store("value"),
        instr_load("value"),
        instr_push_number(1),
        instr_eq(),
        instr_if(then_body),
        instr_load("value"),
        instr_push_number(1),
        instr_add(),
        instr_push_number(42),
        instr_eq(),
        instr_return(),
    ]

    @result = run_tiny(bytecode)
    core.io.println("step-d result=", result)
    out result
}
