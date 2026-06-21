use std

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
        .SAFE => std.io.println("status: SAFE"),
        .LOW => std.io.println("status: LOW"),
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
    drum (days) {
        charge = apply_day(charge, solar, usage)
        std.io.println("day charge: ", charge, " Wh")
    }
    @final = percent(charge, capacity)
    @status = classify(final, safe_min)
    std.io.println("final charge: ", final, " %")
    print_status(status)
    out none
}
