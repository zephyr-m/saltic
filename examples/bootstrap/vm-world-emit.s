use core

program() {
    @box = world.spawn("box")
    world.emit(box, "place", 10, 20)
    world.emit(box, "move", 5, 0)
    world.step()

    @trace = world.trace_text()
    @state = world.state_text()
    @replayed = world.replay(trace)

    world.trace()
    world.state()
    core.io.println(state == replayed)
    out state
}
