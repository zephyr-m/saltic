use core

program() {
    @box = world.spawn("box")

    world.emit(box, "place", 10, 20)
    world.emit(box, "move", 5, 0)
    world.step()

    @state = world.state_text()

    world.trace()
    world.state()
    out state
}
