use core

Sort = Box {
    values = []
    ticks = 0
    work = 0
}

skill replace(values, target, value) {
    @result = []
    @index = 0
    @count = core.group.count(values)

    drum (count) {
        (index == target) {
            result = core.group.add(result, value)
        }
        (index < target) {
            result = core.group.add(result, core.group.at(values, index))
        }
        (index > target) {
            result = core.group.add(result, core.group.at(values, index))
        }
        index = index + 1
    }

    out result
}

skill compare(values, left_at) {
    @left = core.group.at(values, left_at)
    @right = core.group.at(values, left_at + 1)

    (left > right) {
        @next = replace(values, left_at, right)
        out replace(next, left_at + 1, left)
    }

    out values
}

skill phase(values, offset, mass) {
    @next = values
    @index = offset
    @count = core.group.count(values)
    @used = 0
    @ticks = 0
    @work = 0

    drum (count) {
        (index + 1 < count) {
            next = compare(next, index)
            used = used + 1
            work = work + 1
            index = index + 2

            (used == mass) {
                ticks = ticks + 1
                used = 0
            }
        }
    }

    (used > 0) {
        ticks = ticks + 1
    }

    out Sort { values = next ticks = ticks work = work }
}

skill fixed_mass(phase) {
    out 4
}

skill wide_mass(phase) {
    out 25
}

skill changing_mass(phase) {
    (phase < 10) { out 4 }
    (phase < 20) { out 12 }
    (phase < 30) { out 2 }
    (phase < 40) { out 20 }
    out 6
}

skill sort_fixed(values, mass) {
    @next = values
    @phase_at = 0
    @offset = 0
    @ticks = 0
    @work = 0
    @count = core.group.count(values)

    drum (count) {
        @step = phase(next, offset, mass)
        next = step.values
        ticks = ticks + step.ticks
        work = work + step.work
        phase_at = phase_at + 1

        @even = offset == 0
        (even == yes) { offset = 1 }
        (even == no) { offset = 0 }
    }

    out Sort { values = next ticks = ticks work = work }
}

skill sort_changing(values) {
    @next = values
    @phase_at = 0
    @offset = 0
    @ticks = 0
    @work = 0
    @count = core.group.count(values)

    drum (count) {
        @mass = changing_mass(phase_at)
        @step = phase(next, offset, mass)
        next = step.values
        ticks = ticks + step.ticks
        work = work + step.work
        phase_at = phase_at + 1

        @even = offset == 0
        (even == yes) { offset = 1 }
        (even == no) { offset = 0 }
    }

    out Sort { values = next ticks = ticks work = work }
}

skill valid(values) {
    @ready = yes
    @index = 0
    @count = core.group.count(values)

    drum (count) {
        (index + 1 < count) {
            (core.group.at(values, index) > core.group.at(values, index + 1)) {
                ready = no
            }
        }
        index = index + 1
    }

    out ready
}

program() {
    @values = [
        49, 12, 37, 4, 28, 45, 1, 33, 18, 41,
        7, 25, 39, 10, 31, 47, 2, 21, 35, 14,
        43, 6, 29, 16, 48, 0, 24, 38, 9, 32,
        19, 44, 5, 27, 13, 40, 8, 34, 22, 46,
        3, 30, 17, 42, 11, 26, 36, 15, 23, 20,
    ]

    @four = sort_fixed(values, 4)
    @twenty_five = sort_fixed(values, 25)
    @changing = sort_changing(values)

    core.io.println("4 agents:        ticks=", four.ticks, " work=", four.work, " valid=", valid(four.values))
    core.io.println("25 agents:       ticks=", twenty_five.ticks, " work=", twenty_five.work, " valid=", valid(twenty_five.values))
    core.io.println("changing agents: ticks=", changing.ticks, " work=", changing.work, " valid=", valid(changing.values))
    out none
}
