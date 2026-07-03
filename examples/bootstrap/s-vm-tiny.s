use tiny_vm.core

program() {
    @bytecode = [
        instr_push_number(10),
        instr_store("x"),
        instr_load("x"),
        instr_push_number(5),
        instr_add(),
        instr_push_number(2),
        instr_mul(),
        instr_push_number(10),
        instr_sub(),
        instr_push_number(2),
        instr_div(),
        instr_store("y"),
        instr_push_text("tiny-vm result="),
        instr_load("y"),
        instr_call_boundary("core.io.println", 2),
        instr_load("y"),
        instr_return(),
    ]

    @result = run_tiny(bytecode)
    out result
}
