import framebuf


class SSD1306_I2C(framebuf.FrameBuffer):
    def __init__(self, width, height, i2c, addr=0x3C):
        self.width = width
        self.height = height
        self.i2c = i2c
        self.addr = addr
        self.buffer = bytearray(width * height // 8)
        super().__init__(self.buffer, width, height, framebuf.MONO_VLSB)
        self._init_display()

    def _command(self, value):
        self.i2c.writeto(self.addr, bytes((0x80, value)))

    def _init_display(self):
        for command in (
            0xAE, 0x20, 0x00, 0x40, 0xA1, 0xC8,
            0x81, 0xCF, 0xA6, 0xA8, self.height - 1,
            0xD3, 0x00, 0xD5, 0x80, 0xD9, 0xF1,
            0xDA, 0x12, 0xDB, 0x40, 0x8D, 0x14,
            0xA4, 0xAF,
        ):
            self._command(command)
        self.fill(0)
        self.show()

    def show(self):
        self._command(0x21)
        self._command(0)
        self._command(self.width - 1)
        self._command(0x22)
        self._command(0)
        self._command(self.height // 8 - 1)
        self.i2c.writevto(self.addr, (b"\x40", self.buffer))
