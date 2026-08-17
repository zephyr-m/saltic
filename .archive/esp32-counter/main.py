import framebuf
from machine import I2C, Pin
from time import sleep_ms, ticks_diff, ticks_ms

from ssd1306 import SSD1306_I2C


BUTTON_PIN = 18
DEBOUNCE_MS = 35

i2c = I2C(0, sda=Pin(21), scl=Pin(22), freq=400_000)
display = SSD1306_I2C(128, 64, i2c)
button = Pin(BUTTON_PIN, Pin.IN, Pin.PULL_UP)
text_buffer = bytearray(80)
text_frame = framebuf.FrameBuffer(text_buffer, 80, 8, framebuf.MONO_VLSB)


def draw_scaled_text(text, x, y, scale):
    width = len(text) * 8
    text_frame.fill(0)
    text_frame.text(text, 0, 0, 1)

    for source_y in range(8):
        for source_x in range(width):
            if text_frame.pixel(source_x, source_y):
                display.fill_rect(
                    x + source_x * scale,
                    y + source_y * scale,
                    scale,
                    scale,
                    1,
                )


def draw_counter(value):
    text = str(value)
    scale = 4 if len(text) <= 4 else 2
    width = len(text) * 8 * scale

    display.fill(0)
    display.text("COUNTER", 36, 0, 1)
    draw_scaled_text(text, (128 - width) // 2, 22, scale)
    display.show()


counter = 0
stable_state = button.value()
last_reading = stable_state
last_change = ticks_ms()

draw_counter(counter)

while True:
    reading = button.value()

    if reading != last_reading:
        last_reading = reading
        last_change = ticks_ms()

    if ticks_diff(ticks_ms(), last_change) >= DEBOUNCE_MS and reading != stable_state:
        stable_state = reading

        if stable_state == 0:
            counter += 1
            draw_counter(counter)

    sleep_ms(5)
