Ink = enum {
    BACKGROUND,
    FOREGROUND,
}

GRAPHICS_CREAM = 16446696
GRAPHICS_CACAO = 3418660

Screen = Box {
    memory = []
    width = 0
    height = 0
}

skill graphics_open() {
    @memory = framebuffer_open()
    out Screen {
        memory = memory
        width = FRAMEBUFFER_WIDTH
        height = FRAMEBUFFER_HEIGHT
    }
}

skill graphics_color(ink) {
    (ink == Ink.FOREGROUND) {
        out GRAPHICS_CACAO
    }
    out GRAPHICS_CREAM
}

skill graphics_pixel(screen, x, y, ink) {
    @inside = yes
    (x < 0) { inside = no }
    (y < 0) { inside = no }
    ((x < screen.width) == no) { inside = no }
    ((y < screen.height) == no) { inside = no }

    (inside == yes) {
        framebuffer_store(screen.memory, x, y, graphics_color(ink))
    }
    out none
}

skill graphics_fill(screen, ink) {
    @color = graphics_color(ink)
    @count = screen.width * screen.height
    @index = 0
    drum (count) {
        core.mem.store32(screen.memory, index * 4, color)
        index = index + 1
    }
    out none
}

skill graphics_rect(screen, x, y, width, height, ink) {
    @row = 0
    drum (height) {
        @column = 0
        drum (width) {
            graphics_pixel(screen, x + column, y + row, ink)
            column = column + 1
        }
        row = row + 1
    }
    out none
}
