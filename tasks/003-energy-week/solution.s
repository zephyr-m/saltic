use core

Status = enum {
    SAFE,
    LOW,
}

skill apply_day(charge, solar, usage) {
    out charge + solar - usage
}

skill percent(value, capacity) {
    out value * 100 / capacity
}

skill classify(charge, safe_min) {
    (charge > safe_min) {
        out Status.SAFE
    }
    out Status.LOW
}

skill print_status(status) {
    (status) {
        .SAFE => core.io.println("status: SAFE"),
        .LOW => core.io.println("status: LOW"),
    }
    out none
}

program() {
    @capacity = 12000
    @charge = 9000
    @solar = 2500
    @usage = 3300
    @safe_min = 30
    @days = 3
    @day = 1
    drum (days) {
        charge = apply_day(charge, solar, usage)
        core.io.println("day ", day, ": ", charge, " Wh")
        day = day + 1
    }
    @final = percent(charge, capacity)
    @status = classify(final, safe_min)
    core.io.println("final charge: ", final, " %")
    print_status(status)
    out none
}
