"""Иконки UIEngine в духе lucide: линии на сетке 24, толщина 2, круглые концы.

Каждая иконка — набор ломаных; покрытие пикселя считается по расстоянию до
отрезков (8 × 8 проб) и пишется в icons/generated/set16.saltic полутонами.
    python3 os/uiengine/tools/icons.py [--preview out.png]
"""
import math
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TARGET = ROOT / "os/uiengine/icons/generated"
SIZES = [16, 12, 28]
SIZE = 16
STROKE = 2.0
PROBES = 8
LEVELS = 15


def circle(cx, cy, r, steps=24):
    return [(cx + r * math.cos(2 * math.pi * i / steps), cy + r * math.sin(2 * math.pi * i / steps)) for i in range(steps + 1)]


def arc(cx, cy, r, start, end, steps=8):
    return [(cx + r * math.cos(math.radians(start + (end - start) * i / steps)), cy + r * math.sin(math.radians(start + (end - start) * i / steps))) for i in range(steps + 1)]


def rect(x, y, w, h, r):
    return arc(x + w - r, y + r, r, -90, 0) + arc(x + w - r, y + h - r, r, 0, 90) + arc(x + r, y + h - r, r, 90, 180) + arc(x + r, y + r, r, 180, 270) + [(x + w - r, y)]


def dot(x, y):
    return [(x, y), (x + 0.01, y)]


ICONS = {
    "check": [[(20, 6), (9, 17), (4, 12)]],
    "chevron-down": [[(6, 9), (12, 15), (18, 9)]],
    "chevron-up": [[(18, 15), (12, 9), (6, 15)]],
    "chevron-right": [[(9, 18), (15, 12), (9, 6)]],
    "chevron-left": [[(15, 18), (9, 12), (15, 6)]],
    "x": [[(18, 6), (6, 18)], [(6, 6), (18, 18)]],
    "plus": [[(5, 12), (19, 12)], [(12, 5), (12, 19)]],
    "minus": [[(5, 12), (19, 12)]],
    "search": [circle(11, 11, 8), [(21, 21), (16.65, 16.65)]],
    "info": [circle(12, 12, 10), [(12, 16), (12, 12)], dot(12, 8)],
    "alert": [circle(12, 12, 10), [(12, 8), (12, 12)], dot(12, 16)],
    "menu": [[(4, 6), (20, 6)], [(4, 12), (20, 12)], [(4, 18), (20, 18)]],
    "more": [dot(5, 12), dot(12, 12), dot(19, 12)],
    "arrow-right": [[(5, 12), (19, 12)], [(12, 5), (19, 12), (12, 19)]],
    "calendar": [rect(3, 4, 18, 18, 2), [(16, 2), (16, 6)], [(8, 2), (8, 6)], [(3, 10), (21, 10)]],
    "user": [circle(12, 7, 4), [(19, 21), (19, 19)] + arc(15, 19, 4, 0, -90) + [(9, 15)] + arc(9, 19, 4, -90, -180) + [(5, 21)]],
    "target": [circle(12, 12, 3), circle(12, 12, 8, 16)],
    "home": [[(3, 10), (12, 3), (21, 10), (21, 21), (3, 21), (3, 10)], [(9, 21), (9, 13), (15, 13), (15, 21)]],
    "bell": [arc(12, 9, 6, 180, 360) + [(18, 16), (20, 18), (4, 18), (6, 16), (6, 9)], [(10, 21), (14, 21)]],
    "mail": [rect(2, 4, 20, 16, 2), [(22, 7), (12, 13), (2, 7)]],
    "circle": [circle(12, 12, 10)],
    "dot": [dot(12, 12)],
    "loader": [arc(12, 12, 9, -90, 200, 24)],
    "chevrons": [[(7, 15), (12, 20), (17, 15)], [(7, 9), (12, 4), (17, 9)]],
    "folder": [[(4, 20), (20, 20)] + arc(20, 18, 2, 90, 0) + [(22, 8)] + arc(20, 8, 2, 0, -90) + [(12.1, 6), (9.6, 3.9), (4, 3.9)] + arc(4, 5.9, 2, -90, -180) + [(2, 18)] + arc(4, 18, 2, 180, 90)],
    "file": [[(15, 2), (6, 2)] + arc(6, 4, 2, -90, -180) + [(4, 20)] + arc(6, 20, 2, 180, 90) + [(18, 22)] + arc(18, 20, 2, 90, 0) + [(20, 7), (15, 2)], [(14, 2), (14, 6)] + arc(16, 6, 2, 180, 90) + [(20, 8)]],
    "leaf": [[(11, 20), (7, 17.5), (6, 13), (7.5, 9), (11, 6.5), (15, 5.5), (19, 2), (20.5, 5.5), (21, 10), (19.5, 15), (16, 18.5), (11, 20)], [(2, 21), (4, 18), (7, 15.5), (10, 13.5), (13, 12)]],
    "terminal": [[(4, 17), (10, 11), (4, 5)], [(12, 19), (20, 19)]],
    "calculator": [rect(4, 2, 16, 20, 2), [(8, 6), (16, 6)], dot(8, 11), dot(12, 11), dot(16, 11), dot(8, 15), dot(12, 15), dot(16, 15), dot(8, 18.5), dot(12, 18.5), dot(16, 18.5)],
    "activity": [[(22, 12), (18, 12), (15, 21), (9, 3), (6, 12), (2, 12)]],
    "tasks": [[(3, 7), (5, 9), (9, 5)], [(3, 17), (5, 19), (9, 15)], [(13, 6), (21, 6)], [(13, 12), (21, 12)], [(13, 18), (21, 18)]],
    "clock": [circle(12, 12, 10), [(12, 6), (12, 12), (16, 14)]],
    "code": [[(16, 18), (22, 12), (16, 6)], [(8, 6), (2, 12), (8, 18)]],
    "gear": [circle(12, 12, 3, 12), circle(12, 12, 7.5, 20)] + [[(12 + 7.5 * math.cos(math.radians(a)), 12 + 7.5 * math.sin(math.radians(a))), (12 + 10 * math.cos(math.radians(a)), 12 + 10 * math.sin(math.radians(a)))] for a in range(0, 360, 45)],
    "gauge": [arc(12, 15, 9, 180, 360, 16), [(12, 15), (16, 10)]],
    "flask": [[(9, 2), (15, 2)], [(10, 2), (10, 9), (4.5, 18.5), (5.5, 21), (18.5, 21), (19.5, 18.5), (14, 9), (14, 2)], [(7, 15), (17, 15)]],
    "play": [[(6, 3), (20, 12), (6, 21), (6, 3)]],
    "route": [circle(6, 19, 3, 12), circle(18, 5, 3, 12), [(9, 19), (17.5, 19)] + arc(17.5, 15.5, 3.5, 90, -90) + [(6.5, 12)] + arc(6.5, 8.5, 3.5, 90, 270) + [(15, 5)]],
    "notes": [[(15, 2), (6, 2)] + arc(6, 4, 2, -90, -180) + [(4, 20)] + arc(6, 20, 2, 180, 90) + [(18, 22)] + arc(18, 20, 2, 90, 0) + [(20, 7), (15, 2)], [(8, 13), (16, 13)], [(8, 17), (16, 17)], [(8, 9), (10, 9)]],
    "image": [rect(3, 3, 18, 18, 2), circle(9, 9, 2, 12), [(21, 15), (16, 10), (5, 21)]],
}


def segment_distance(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    length = dx * dx + dy * dy
    t = 0.0 if length == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / length))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def rasterize(lines, size, stroke):
    scale = 24 / size
    half = stroke / 2
    segments = [(a, b) for line in lines for a, b in zip(line, line[1:])]
    pixels = []
    for row in range(size):
        for column in range(size):
            inside = 0
            for sy in range(PROBES):
                for sx in range(PROBES):
                    px = (column + (sx + 0.5) / PROBES) * scale
                    py = (row + (sy + 0.5) / PROBES) * scale
                    if any(segment_distance(px, py, *a, *b) <= half for a, b in segments):
                        inside += 1
            pixels.append(round(inside * LEVELS / (PROBES * PROBES)))
    return pixels


def write_preview(path, icons):
    width, height = len(icons) * (SIZE + 8) + 8, SIZE + 16
    image = [[255] * width for _ in range(height)]
    for index, pixels in enumerate(icons):
        for row in range(SIZE):
            for column in range(SIZE):
                image[8 + row][8 + index * (SIZE + 8) + column] = 255 - pixels[row * SIZE + column] * 231 // LEVELS
    raw = b"".join(b"\x00" + bytes(line) for line in image)

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)
    Path(path).write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 0, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


if "--preview" in sys.argv:
    write_preview(sys.argv[sys.argv.index("--preview") + 1], [rasterize(lines, SIZE, STROKE) for lines in ICONS.values()])
    print("icons: образец записан", flush=True)
    sys.exit(0)
TARGET.mkdir(parents=True, exist_ok=True)
names = ", ".join(f'"{name}"' for name in ICONS)
for size in SIZES:
    rendered = [rasterize(lines, size, STROKE * 24 / 16 * size / 24 * 16 / size) for lines in ICONS.values()]
    body = ",\n".join('    "' + "".join(f"{level:x}" for level in pixels) + '"' for pixels in rendered)
    target = TARGET / f"set{size}.saltic"
    target.write_text(f"SIZE = {size}\nNAMES = [{names}]\nPIXELS = [\n{body}\n]\n")
    print(f"icons: {len(rendered)} иконок {size}×{size} → {target.relative_to(ROOT)}, {target.stat().st_size} байт", flush=True)
