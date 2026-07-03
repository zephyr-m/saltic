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

skill show_panel(path) {
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

    ui.panel("family-ledger")
    ui.text("Family ledger")
    ui.field("kind", "Kind")
    ui.field("amount", "Amount")
    ui.field("label", "Label")
    ui.button("add", "Add")
    ui.value("income", income)
    ui.value("expenses", expenses)
    ui.value("debt", debt)
    ui.value("free", free)
    ui.value("status", status(free))
    ui.present()
    ui.trace()
    out none
}

program(path) {
    show_panel(path)
    out none
}

