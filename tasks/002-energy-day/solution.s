use std

Status = enum {
    SAFE,
    LOW,
}

skill end_energy(start, solar, usage) {
    out start + solar - usage
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
    @start = 7000
    @solar = 3200
    @usage = 4500
    @safe_min = 30
    @end = end_energy(start, solar, usage)
    @charge = percent(end, capacity)
    @status = classify(charge, safe_min)
    std.io.println("end: ", end, " Wh")
    std.io.println("charge: ", charge, " %")
    print_status(status)
    out none
}
