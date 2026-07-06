use core

status = enum {
    running,
    returned,
    error,
}

frame = Box {
    name = ""
    ip = 0
    params = []
    instructions = []
    env = []
    stack = []
    returned = no
    result = none
}

state = Box {
    frames = []
    globals = []
    modules = []
    effects = []
    world = none
    visual = none
    status = status.running
    error = none
}

input = Box {
    frame = none
    stack = none
    env = none
    returned = no
}

output = Box {
    frame = none
    stack = none
    env = none
    returned = no
}

contract = Box {
    input = input {}
    output = output {}
}

skill s_vm_frame_contract() {
    out contract {}
}

skill makeframe(name, instructions) {
    out frame {
        name = name
        ip = 0
        params = []
        instructions = instructions
        env = []
        stack = []
        returned = no
        result = none
    }
}

skill emptystate() {
    out state {
        frames = []
        globals = []
        modules = []
        effects = []
        world = none
        visual = none
        status = status.running
        error = none
    }
}

skill pushframe(frame) {
    out state {
        frames = [frame]
        globals = []
        modules = []
        effects = []
        world = none
        visual = none
        status = status.running
        error = none
    }
}

skill s_vm_frame_stub(in) {
    out output {
        frame = in.frame
        stack = in.stack
        env = in.env
        returned = in.returned
    }
}
