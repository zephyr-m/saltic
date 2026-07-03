use core
use tiny_vm.core

program() {
    @rescue_body = body_one(instr_push_number(42))

    @bytecode = [
        instr_push_number(10),
        instr_push_number(0),
        instr_div(),
        instr_rescue("err", rescue_body),
        instr_push_number(42),
        instr_eq(),
        instr_return(),
    ]

    @result = run_tiny(bytecode)
    core.io.println("step-rescue result=", result)
    out result
}
