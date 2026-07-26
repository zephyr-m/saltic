use core
use s.run.vm.core

program() {
    @ok_body = body_one(instr_push_number(42))
    @error_body = body_one(instr_push_number(0))
    @cases = switch_two(switch_case("ERROR", error_body), switch_case("OK", ok_body))

    @bytecode = [
        instr_push_enum("Status", "OK"),
        instr_switch(cases),
        instr_push_number(42),
        instr_eq(),
        instr_return(),
    ]

    @result = run_tiny(bytecode)
    core.io.println("step-switch result=", result)
    out result
}
