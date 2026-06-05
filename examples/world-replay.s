program() {
    @box = world.spawn("box")
    world.place(box, 10, 20)
    world.move(box, 5, 0)
    @trace = world.trace_text()
    @state = world.state_text()
    @replayed = world.replay(trace)
    host.io.println(host.str.trim(trace))
    host.io.println(host.str.trim(replayed))
    host.io.println(state == replayed)
    out none
}
