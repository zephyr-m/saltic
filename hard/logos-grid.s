use core

// Protocol-level visual experiment. This is not the normative Logos v0 machine;
// the normative S model is hard/logos-v0.s.

Logos = Box {
    signal = 0
}

skill replace(logos, target, value) {
    @next = []
    @index = 0
    @count = core.group.count(logos)

    drum (count) {
        (index == target) {
            next = core.group.add(next, value)
        }
        (index < target) {
            next = core.group.add(next, core.group.at(logos, index))
        }
        (index > target) {
            next = core.group.add(next, core.group.at(logos, index))
        }
        index = index + 1
    }

    out next
}

skill create_grid() {
    @logos = []
    @index = 0

    drum (16 * 16) {
        logos = core.group.add(logos, Logos {})
        index = index + 1
    }

    out replace(logos, 7 * 16 + 7, Logos { signal = 4 })
}

skill emitted(logos, index) {
    @logos_item = core.group.at(logos, index)
    (logos_item.signal == 4) { out 1 }
    out 0
}

skill react(logos, index, row, column) {
    @logos_item = core.group.at(logos, index)

    (logos_item.signal > 0) {
        out Logos { signal = logos_item.signal - 1 }
    }

    @inbox = 0
    (row > 0) { inbox = inbox + emitted(logos, index - 16) }
    (row + 1 < 16) { inbox = inbox + emitted(logos, index + 16) }
    (column > 0) { inbox = inbox + emitted(logos, index - 1) }
    (column + 1 < 16) { inbox = inbox + emitted(logos, index + 1) }

    (inbox > 0) { out Logos { signal = 4 } }
    out Logos {}
}

skill tick(logos) {
    @next = []
    @index = 0
    @row = 0
    @column = 0

    drum (16 * 16) {
        next = core.group.add(next, react(logos, index, row, column))
        index = index + 1
        column = column + 1
        (column == 16) {
            column = 0
            row = row + 1
        }
    }

    out next
}

skill pixel(logos_item) {
    (logos_item.signal == 4) { out "@" }
    (logos_item.signal == 3) { out "O" }
    (logos_item.signal == 2) { out "o" }
    (logos_item.signal == 1) { out "." }
    out " "
}

skill show_grid(logos, step) {
    core.io.println("tick ", step)
    @row = 0

    drum (16) {
        @line = "|"
        @column = 0
        drum (16) {
            @index = row * 16 + column
            line = host.str.join(line, pixel(core.group.at(logos, index)))
            column = column + 1
        }
        core.io.println(line, "|")
        row = row + 1
    }
    core.io.println("")
    out none
}

program() {
    @logos = create_grid()
    @step = 0

    drum (18) {
        core.io.clear()
        show_grid(logos, step)
        host.time.sleep(120)
        logos = tick(logos)
        step = step + 1
    }

    out none
}
