Crystal = Box {
    name = "crystal"
    height = 4
    base = 2
    color = "cyan"
    spin = 1
}

skill observe_crystal(crystal) {
    visual.sheet("engineering")
    visual.grid(24)
    visual.square_bipyramid(crystal.name, crystal.height, crystal.base, crystal.color)
    visual.rotate(crystal.name, "y", crystal.spin)
    visual.present()
    out none
}

program() {
    @crystal = Crystal {}
    observe_crystal(crystal)
    visual.trace()
    out none
}
