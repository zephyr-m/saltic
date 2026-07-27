use core

Agent = Box {
    id = 0
    value = 0
}

Exchange = Box {
    left = Agent {}
    right = Agent {}
}

Sort = Box {
    agents = []
    rounds = 0
    pulses = 0
}

skill replace(group, target, value) {
    @result = []
    @index = 0
    @count = core.group.count(group)

    drum (count) {
        (index == target) {
            result = core.group.add(result, value)
        }
        (index < target) {
            result = core.group.add(result, core.group.at(group, index))
        }
        (index > target) {
            result = core.group.add(result, core.group.at(group, index))
        }
        index = index + 1
    }

    out result
}

skill interact(left, right) {
    (left.value > right.value) {
        out Exchange {
            left = Agent { id = left.id value = right.value }
            right = Agent { id = right.id value = left.value }
        }
    }

    out Exchange { left = left right = right }
}

skill pulse(agents, offset) {
    @next = agents
    @index = offset
    @count = core.group.count(agents)

    drum (count) {
        (index + 1 < count) {
            @left = core.group.at(next, index)
            @right = core.group.at(next, index + 1)
            @exchange = interact(left, right)
            next = replace(next, index, exchange.left)
            next = replace(next, index + 1, exchange.right)
            index = index + 2
        }
    }

    out next
}

skill settled(agents) {
    @ready = yes
    @index = 0
    @count = core.group.count(agents)

    drum (count) {
        (index + 1 < count) {
            @left = core.group.at(agents, index)
            @right = core.group.at(agents, index + 1)
            (left.value > right.value) {
                ready = no
            }
        }
        index = index + 1
    }

    out ready
}

skill sort(agents) {
    @next = agents
    @rounds = 0
    @pulses = 0
    @count = core.group.count(agents)

    drum (count) {
        (settled(next) == no) {
            next = pulse(next, 0)
            next = pulse(next, 1)
            rounds = rounds + 1
            pulses = pulses + count - 1
        }
    }

    out Sort { agents = next rounds = rounds pulses = pulses }
}

skill show_agents(agents) {
    @index = 0
    @count = core.group.count(agents)

    drum (count) {
        @agent = core.group.at(agents, index)
        core.io.show(agent.value)
        index = index + 1
    }

    out none
}

program() {
    @agents = [
        Agent { id = 0 value = 9 },
        Agent { id = 1 value = 1 },
        Agent { id = 2 value = 7 },
        Agent { id = 3 value = 3 },
        Agent { id = 4 value = 8 },
        Agent { id = 5 value = 2 },
        Agent { id = 6 value = 6 },
        Agent { id = 7 value = 4 },
        Agent { id = 8 value = 5 },
        Agent { id = 9 value = 0 },
    ]

    @result = sort(agents)
    show_agents(result.agents)
    core.io.println("rounds ", result.rounds)
    core.io.println("pulses ", result.pulses)
    out none
}
