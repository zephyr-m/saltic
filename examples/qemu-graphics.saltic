program() {
    @screen = graphics_open() rescue |err| {
        uart_line("framebuffer error")
        out err
    }

    graphics_fill(screen, Ink.BACKGROUND)
    graphics_rect(screen, 128, 96, 1024, 528, Ink.FOREGROUND)
    graphics_rect(screen, 160, 128, 960, 464, Ink.BACKGROUND)
    graphics_rect(screen, 224, 176, 832, 368, Ink.FOREGROUND)
    graphics_rect(screen, 256, 208, 768, 304, Ink.BACKGROUND)
    graphics_text(screen, 604, 302, "SALTIC 1.0.0", 1, Ink.FOREGROUND)
    graphics_text(screen, 592, 322, "BARE METAL RV32I", 1, Ink.FOREGROUND)

    @keyboard = keyboard_open()
    (keyboard.ready == no) {
        uart_line(core.str.add("ошибка клавиатуры, этап ", core.num.text(keyboard.status)))
        out error.KeyboardUnavailable
    }
    @field = text_field_new(340, 360, 600)
    text_field_draw(screen, field)

    uart_line("клавиатура Saltic готова")
    drum (268435455) {
        drum (268435455) {
            @event = keyboard_poll(keyboard)
            (event.ready == yes) {
                (event.value > 0) {
                    field = text_field_key(field, event.code, keyboard.shift)
                    text_field_draw(screen, field)
                }
            }
        }
    }

    out none
}
