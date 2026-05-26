program() {
    @box = world.spawn("box")
    world.place(box, 10, 20)
    world.move(box, 5, 0)
    world.trace()
    world.state()
    out none
}
