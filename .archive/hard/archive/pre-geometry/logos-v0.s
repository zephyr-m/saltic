use core

Reaction = Box {
    valid = no
    opcode = 0
    target = 0
}

Logos = Box {
    counter = 0
    halted = no
    inc = Reaction {}
    dec = Reaction {}
    zero = Reaction {}
    outbox_valid = no
    outbox_opcode = 0
    outbox_data = 0
    outbox_target = 0
}

skill ready(logos, outbox_ready) {
    (logos.halted == yes) { out no }
    (logos.outbox_valid == no) { out yes }
    out outbox_ready
}

skill configure(logos, counter, inc, dec, zero) {
    out Logos {
        counter = counter
        halted = no
        inc = inc
        dec = dec
        zero = zero
        outbox_valid = no
    }
}

skill step(logos, inbox_valid, opcode, data, outbox_ready) {
    @counter = logos.counter
    @halted = logos.halted
    @out_valid = logos.outbox_valid
    @out_opcode = logos.outbox_opcode
    @out_data = logos.outbox_data
    @out_target = logos.outbox_target

    (out_valid == yes) {
        (outbox_ready == yes) { out_valid = no }
    }

    @accepted = inbox_valid == yes
    (ready(logos, outbox_ready) == no) { accepted = no }

    (accepted == yes) {
        (opcode == 1) {
            (counter == 18446744073709551615) { counter = 0 }
            (counter < 18446744073709551615) { counter = counter + 1 }
            (logos.inc.valid == yes) {
                out_valid = yes
                out_opcode = logos.inc.opcode
                out_data = data
                out_target = logos.inc.target
            }
        }

        (opcode == 2) {
            (counter == 0) {
                (logos.zero.valid == yes) {
                    out_valid = yes
                    out_opcode = logos.zero.opcode
                    out_data = data
                    out_target = logos.zero.target
                }
            }
            (counter > 0) {
                counter = counter - 1
                (logos.dec.valid == yes) {
                    out_valid = yes
                    out_opcode = logos.dec.opcode
                    out_data = data
                    out_target = logos.dec.target
                }
            }
        }

        (opcode == 3) { halted = yes }
    }

    out Logos {
        counter = counter
        halted = halted
        inc = logos.inc
        dec = logos.dec
        zero = logos.zero
        outbox_valid = out_valid
        outbox_opcode = out_opcode
        outbox_data = out_data
        outbox_target = out_target
    }
}

program() {
    @inc = Reaction { valid = yes opcode = 2 target = 9 }
    @dec = Reaction { valid = yes opcode = 1 target = 10 }
    @zero = Reaction { valid = yes opcode = 3 target = 11 }
    @logos = configure(Logos {}, 1, inc, dec, zero)

    logos = step(logos, yes, 1, 4660, yes)
    core.io.println("inc counter=", logos.counter, " op=", logos.outbox_opcode, " target=", logos.outbox_target, " data=", logos.outbox_data)

    logos = step(logos, yes, 2, 22136, no)
    core.io.println("stall counter=", logos.counter, " data=", logos.outbox_data)

    logos = step(logos, yes, 2, 22136, yes)
    core.io.println("dec counter=", logos.counter, " op=", logos.outbox_opcode, " target=", logos.outbox_target, " data=", logos.outbox_data)

    logos = step(logos, yes, 2, 0, yes)
    logos = step(logos, yes, 2, 57072, yes)
    core.io.println("zero counter=", logos.counter, " op=", logos.outbox_opcode, " target=", logos.outbox_target, " data=", logos.outbox_data)

    logos = step(logos, yes, 3, 0, yes)
    core.io.println("halted=", logos.halted, " ready=", ready(logos, yes))
    out none
}
