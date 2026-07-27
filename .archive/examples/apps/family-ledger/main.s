use core

skill amount(line) {
    @parts = core.str.split(line, " ")
    out core.num.parse(core.group.at(parts, 2))
}

skill kind(line) {
    @parts = core.str.split(line, " ")
    out core.group.at(parts, 0)
}

skill status(free) {
    (free < 0) {
        out "danger"
    }
    out "alive"
}

skill report(path) {
    @text = core.file.read_text(path)
    @lines = core.str.lines(text)

    @income = 0
    @expenses = 0
    @debt = 0
    @index = 0

    drum (core.group.count(lines)) {
        @line = core.group.at(lines, index)
        @line_kind = kind(line)
        @line_amount = amount(line)

        (core.str.eq(line_kind, "income")) {
            income = income + line_amount
        }

        (core.str.eq(line_kind, "expense")) {
            expenses = expenses + line_amount
        }

        (core.str.eq(line_kind, "debt")) {
            debt = debt + line_amount
        }

        index = index + 1
    }

    @free = income - expenses

    core.io.println("income: ", income)
    core.io.println("expenses: ", expenses)
    core.io.println("debt: ", debt)
    core.io.println("free: ", free)
    core.io.println("status: ", status(free))
    out none
}

program(path) {
    report(path)
    out none
}
