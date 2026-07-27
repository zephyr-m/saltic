use core
use s.run.vm.core

program() {
    @loop_body = body_four(instr_load("sum"), instr_push_number(2), instr_add(), instr_store("sum"))

    @bytecode = [
        instr_push_number(0),
        instr_store("sum"),
        instr_push_number(4),
        instr_drum(loop_body),
        instr_load("sum"),
        instr_push_number(8),
        instr_eq(),
        instr_return(),
    ]

    @result = run_tiny(bytecode)
    core.io.println("step-drum result=", result)
    out result
}
