use std

skill amount(line) {
    @parts = std.str.split(line, " ")
    out std.num.parse(std.group.at(parts, 2))
}

skill kind(line) {
    @parts = std.str.split(line, " ")
    out std.group.at(parts, 0)
}

skill status(free) {
    (free < 0) {
        out "danger"
    }
    out "alive"
}

skill report(path) {
    @text = std.file.read_text(path)
    @lines = std.str.lines(text)

    @income = 0
    @expenses = 0
    @debt = 0
    @index = 0

    drum (std.group.count(lines)) {
        @line = std.group.at(lines, index)
        @line_kind = kind(line)
        @line_amount = amount(line)

        (std.str.eq(line_kind, "income")) {
            income = income + line_amount
        }

        (std.str.eq(line_kind, "expense")) {
            expenses = expenses + line_amount
        }

        (std.str.eq(line_kind, "debt")) {
            debt = debt + line_amount
        }

        index = index + 1
    }

    @free = income - expenses

    std.io.println("income: ", income)
    std.io.println("expenses: ", expenses)
    std.io.println("debt: ", debt)
    std.io.println("free: ", free)
    std.io.println("status: ", status(free))
    out none
}

program(path) {
    report(path)
    out none
}
