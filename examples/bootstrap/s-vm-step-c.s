use core
use s.run.vm.core

program() {
    @bytecode = [
        instr_push_number(10),
        instr_push_number(20),
        instr_box_new("Point", "x", "y", 2),
        instr_store("point"),
        instr_load("point"),
        instr_field("x"),
        instr_store("x"),
        instr_load("point"),
        instr_field("y"),
        instr_store("y"),
        instr_load("x"),
        instr_load("y"),
        instr_add(),
        instr_store("sum"),
        instr_load("x"),
        instr_load("sum"),
        instr_group(2),
        instr_store("pair"),
        instr_load("sum"),
        instr_push_number(30),
        instr_eq(),
        instr_return(),
    ]

    @result = run_tiny(bytecode)
    core.io.println("step-c result=", result)
    out result
}
