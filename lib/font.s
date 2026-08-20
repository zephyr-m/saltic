FONT_FIRST = 32
FONT_LAST = 96
FONT_WIDTH = 5
FONT_HEIGHT = 7

skill font_5x7() {
    out [
        [0, 0, 0, 0, 0, 0, 0],
        [4, 4, 4, 4, 4, 0, 4],
        [10, 10, 10, 0, 0, 0, 0],
        [10, 31, 10, 10, 31, 10, 0],
        [4, 15, 20, 14, 5, 30, 4],
        [24, 25, 2, 4, 8, 19, 3],
        [12, 18, 20, 8, 21, 18, 13],
        [4, 4, 8, 0, 0, 0, 0],
        [2, 4, 8, 8, 8, 4, 2],
        [8, 4, 2, 2, 2, 4, 8],
        [0, 10, 4, 31, 4, 10, 0],
        [0, 4, 4, 31, 4, 4, 0],
        [0, 0, 0, 0, 4, 4, 8],
        [0, 0, 0, 31, 0, 0, 0],
        [0, 0, 0, 0, 0, 4, 4],
        [1, 2, 4, 8, 16, 0, 0],
        [14, 17, 19, 21, 25, 17, 14],
        [4, 12, 4, 4, 4, 4, 14],
        [14, 17, 1, 2, 4, 8, 31],
        [30, 1, 1, 14, 1, 1, 30],
        [2, 6, 10, 18, 31, 2, 2],
        [31, 16, 16, 30, 1, 1, 30],
        [14, 16, 16, 30, 17, 17, 14],
        [31, 1, 2, 4, 8, 8, 8],
        [14, 17, 17, 14, 17, 17, 14],
        [14, 17, 17, 15, 1, 1, 14],
        [0, 4, 4, 0, 4, 4, 0],
        [0, 4, 4, 0, 4, 4, 8],
        [2, 4, 8, 16, 8, 4, 2],
        [0, 0, 31, 0, 31, 0, 0],
        [8, 4, 2, 1, 2, 4, 8],
        [14, 17, 1, 2, 4, 0, 4],
        [14, 17, 23, 21, 23, 16, 14],
        [14, 17, 17, 31, 17, 17, 17],
        [30, 17, 17, 30, 17, 17, 30],
        [14, 17, 16, 16, 16, 17, 14],
        [30, 17, 17, 17, 17, 17, 30],
        [31, 16, 16, 30, 16, 16, 31],
        [31, 16, 16, 30, 16, 16, 16],
        [14, 17, 16, 23, 17, 17, 15],
        [17, 17, 17, 31, 17, 17, 17],
        [14, 4, 4, 4, 4, 4, 14],
        [7, 2, 2, 2, 2, 18, 12],
        [17, 18, 20, 24, 20, 18, 17],
        [16, 16, 16, 16, 16, 16, 31],
        [17, 27, 21, 21, 17, 17, 17],
        [17, 25, 21, 19, 17, 17, 17],
        [14, 17, 17, 17, 17, 17, 14],
        [30, 17, 17, 30, 16, 16, 16],
        [14, 17, 17, 17, 21, 18, 13],
        [30, 17, 17, 30, 20, 18, 17],
        [15, 16, 16, 14, 1, 1, 30],
        [31, 4, 4, 4, 4, 4, 4],
        [17, 17, 17, 17, 17, 17, 14],
        [17, 17, 17, 17, 17, 10, 4],
        [17, 17, 17, 21, 21, 21, 10],
        [17, 17, 10, 4, 10, 17, 17],
        [17, 17, 10, 4, 4, 4, 4],
        [31, 1, 2, 4, 8, 16, 31],
        [14, 8, 8, 8, 8, 8, 14],
        [16, 8, 4, 2, 1, 0, 0],
        [14, 2, 2, 2, 2, 2, 14],
        [4, 10, 17, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 31],
        [8, 4, 2, 0, 0, 0, 0],
    ]
}

skill font_glyph(font, code) {
    @normalized = code
    (normalized > 96) {
        (normalized < 123) {
            normalized = normalized - 32
        }
    }

    @valid = yes
    (normalized < FONT_FIRST) { valid = no }
    (normalized > FONT_LAST) { valid = no }
    (valid == no) { normalized = FONT_FIRST }

    out core.group.at(font, normalized - FONT_FIRST)
}

skill font_divisor(column) {
    (column == 0) { out 16 }
    (column == 1) { out 8 }
    (column == 2) { out 4 }
    (column == 3) { out 2 }
    out 1
}

skill font_draw_glyph(screen, font, x, y, code, scale, ink) {
    @glyph = font_glyph(font, code)
    @row = 0
    drum (FONT_HEIGHT) {
        @mask = core.group.at(glyph, row)
        @column = 0
        drum (FONT_WIDTH) {
            @divisor = font_divisor(column)
            @quotient = mask / divisor
            @bit = quotient - quotient / 2 * 2
            (bit == 1) {
                graphics_rect(screen, x + column * scale, y + row * scale, scale, scale, ink)
            }
            column = column + 1
        }
        row = row + 1
    }
    out none
}

skill graphics_text(screen, x, y, text, scale, ink) {
    @font = font_5x7()
    @origin = x
    @cursor_x = x
    @cursor_y = y
    @index = 0
    @count = core.str.len(text)

    drum (count) {
        @code = core.str.byte(text, index)
        (code == 10) {
            cursor_x = origin
            cursor_y = cursor_y + (FONT_HEIGHT + 1) * scale
        }
        ((code == 10) == no) {
            font_draw_glyph(screen, font, cursor_x, cursor_y, code, scale, ink)
            cursor_x = cursor_x + (FONT_WIDTH + 1) * scale
        }
        index = index + 1
    }
    out none
}
