program() {
    visual.sheet("engineering")
    visual.grid(24)
    visual.square_bipyramid("crystal", 4, 2, "cyan")
    visual.rotate("crystal", "y", 1)
    visual.present()
    visual.trace()
    out visual.trace_text()
}
