use core
use tiny_vm.core

program() {
    @bytecode = [
        instr_push_none(),
        instr_pop(),
        instr_push_error("Manual"),
        instr_pop(),
        instr_push_enum("Status", "OK"),
        instr_pop(),
        instr_push_number(2),
        instr_push_number(3),
        instr_add(),
        instr_store("x"),
        instr_load("x"),
        instr_push_number(10),
        instr_lt(),
        instr_store("y"),
        instr_load("x"),
        instr_push_number(2),
        instr_mul(),
        instr_store("x"),
        instr_load("x"),
        instr_push_number(4),
        instr_sub(),
        instr_store("x"),
        instr_load("x"),
        instr_push_number(3),
        instr_div(),
        instr_store("x"),
        instr_push_number(9),
        instr_push_number(0),
        instr_div(),
        instr_pop(),
        instr_load("x"),
        instr_push_number(2),
        instr_eq(),
        instr_store("x"),
        instr_load("x"),
        instr_store("ok"),
        instr_load("ok"),
        instr_load("y"),
        instr_eq(),
        instr_return(),
    ]

    @result = run_tiny(bytecode)
    core.io.println("step-ab result=", result)
    out result
}
