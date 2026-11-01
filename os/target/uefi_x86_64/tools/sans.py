"""Сглаженный шрифт для Acer: растеризует TrueType в полутона и пишет sans.saltic.

Свой растеризатор, без библиотек: контуры glyf → отрезки → покрытие пикселя
(8 строк проб по вертикали, точная площадь по горизонтали) → 16 уровней.
    python3 tools/sans.py [шрифт.ttf] [размер] [--preview картинка.png]
Без шрифта берёт Noto Sans через fc-match.
"""
import struct
import subprocess
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
TARGET = ROOT / "os/target/uefi_x86_64/sans.saltic"
ROWS = 8
LEVELS = 15
EXTRA = [0x2014, 0x2013, 0x00AB, 0x00BB, 0x00D7, 0x2026, 0x00B0, 0x2116]


def codes():
    """Порядок глифов — тот же, что в sans_index на Saltic."""
    return list(range(32, 127)) + list(range(0x410, 0x450)) + [0x401, 0x451] + EXTRA


class Font:
    def __init__(self, path):
        self.data = Path(path).read_bytes()
        count = struct.unpack(">H", self.data[4:6])[0]
        self.tables = {}
        for index in range(count):
            tag, _, offset, length = struct.unpack(">4sIII", self.data[12 + index * 16:28 + index * 16])
            self.tables[tag.decode()] = (offset, length)
        head = self.table("head")
        self.units = struct.unpack(">H", head[18:20])[0]
        self.long_loca = struct.unpack(">h", head[50:52])[0] == 1
        hhea = self.table("hhea")
        self.ascent, self.descent = struct.unpack(">hh", hhea[4:8])
        self.metrics_count = struct.unpack(">H", hhea[34:36])[0]
        self.cmap = self.read_cmap()

    def table(self, tag):
        offset, length = self.tables[tag]
        return self.data[offset:offset + length]

    def read_cmap(self):
        cmap = self.table("cmap")
        count = struct.unpack(">H", cmap[2:4])[0]
        mapping = {}
        for index in range(count):
            platform, encoding, offset = struct.unpack(">HHI", cmap[4 + index * 8:12 + index * 8])
            sub = cmap[offset:]
            kind = struct.unpack(">H", sub[0:2])[0]
            if platform == 3 and kind == 4:
                segments = struct.unpack(">H", sub[6:8])[0] // 2
                ends = struct.unpack(f">{segments}H", sub[14:14 + segments * 2])
                base = 16 + segments * 2
                starts = struct.unpack(f">{segments}H", sub[base:base + segments * 2])
                deltas = struct.unpack(f">{segments}h", sub[base + segments * 2:base + segments * 4])
                ranges_at = base + segments * 4
                ranges = struct.unpack(f">{segments}H", sub[ranges_at:ranges_at + segments * 2])
                for segment in range(segments):
                    for code in range(starts[segment], ends[segment] + 1):
                        if code == 0xFFFF:
                            continue
                        if ranges[segment] == 0:
                            glyph = (code + deltas[segment]) & 0xFFFF
                        else:
                            at = ranges_at + segment * 2 + ranges[segment] + (code - starts[segment]) * 2
                            glyph = struct.unpack(">H", sub[at:at + 2])[0]
                            glyph = (glyph + deltas[segment]) & 0xFFFF if glyph else 0
                        mapping.setdefault(code, glyph)
        return mapping

    def advance(self, glyph):
        hmtx = self.table("hmtx")
        index = min(glyph, self.metrics_count - 1)
        return struct.unpack(">H", hmtx[index * 4:index * 4 + 2])[0]

    def glyph_bytes(self, glyph):
        loca = self.table("loca")
        if self.long_loca:
            start, end = struct.unpack(">II", loca[glyph * 4:glyph * 4 + 8])
        else:
            start, end = (value * 2 for value in struct.unpack(">HH", loca[glyph * 2:glyph * 2 + 4]))
        return self.table("glyf")[start:end]

    def contours(self, glyph, dx=0.0, dy=0.0, scale=(1.0, 0.0, 0.0, 1.0)):
        data = self.glyph_bytes(glyph)
        if data == b"":
            return []
        count = struct.unpack(">h", data[0:2])[0]
        if count < 0:
            return self.composite(data, dx, dy)
        ends = struct.unpack(f">{count}H", data[10:10 + count * 2])
        at = 10 + count * 2
        at += 2 + struct.unpack(">H", data[at:at + 2])[0]
        total = ends[-1] + 1
        flags = []
        while len(flags) < total:
            flag = data[at]
            at += 1
            flags.append(flag)
            if flag & 8:
                flags.extend([flag] * data[at])
                at += 1
        xs, ys = [], []
        for coords, short, same in ((xs, 2, 16), (ys, 4, 32)):
            value = 0
            for flag in flags:
                if flag & short:
                    step = data[at]
                    at += 1
                    value += step if flag & same else -step
                elif flag & same == 0:
                    value += struct.unpack(">h", data[at:at + 2])[0]
                    at += 2
                coords.append(value)
        a, b, c, d = scale
        result, first = [], 0
        for end in ends:
            points = [(xs[i] * a + ys[i] * c + dx, xs[i] * b + ys[i] * d + dy, flags[i] & 1) for i in range(first, end + 1)]
            result.append(points)
            first = end + 1
        return result

    def composite(self, data, dx, dy):
        at, result = 10, []
        while True:
            flags, glyph = struct.unpack(">HH", data[at:at + 4])
            at += 4
            if flags & 1:
                arg1, arg2 = struct.unpack(">hh", data[at:at + 4])
                at += 4
            else:
                arg1, arg2 = struct.unpack(">bb", data[at:at + 2])
                at += 2
            scale = (1.0, 0.0, 0.0, 1.0)
            if flags & 8:
                value = struct.unpack(">h", data[at:at + 2])[0] / 16384
                scale = (value, 0.0, 0.0, value)
                at += 2
            elif flags & 0x40:
                sx, sy = (v / 16384 for v in struct.unpack(">hh", data[at:at + 4]))
                scale = (sx, 0.0, 0.0, sy)
                at += 4
            elif flags & 0x80:
                scale = tuple(v / 16384 for v in struct.unpack(">hhhh", data[at:at + 8]))
                at += 8
            result += self.contours(glyph, dx + arg1, dy + arg2, scale)
            if flags & 0x20 == 0:
                return result


def flatten(points, steps=8):
    """Контур из точек на кривой и контрольных → замкнутая ломаная."""
    count = len(points)
    start = next((i for i in range(count) if points[i][2]), None)
    if start is None:
        a, b = points[0], points[1]
        points = [((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, 1)] + points
        count, start = len(points), 0
    ordered = points[start:] + points[:start]
    line = [ordered[0][:2]]
    index = 1
    while index <= count:
        point = ordered[index % count]
        if point[2]:
            line.append(point[:2])
            index += 1
            continue
        after = ordered[(index + 1) % count]
        end = after[:2] if after[2] else ((point[0] + after[0]) / 2, (point[1] + after[1]) / 2)
        begin = line[-1]
        for step in range(1, steps + 1):
            t = step / steps
            x = (1 - t) ** 2 * begin[0] + 2 * (1 - t) * t * point[0] + t * t * end[0]
            y = (1 - t) ** 2 * begin[1] + 2 * (1 - t) * t * point[1] + t * t * end[1]
            line.append((x, y))
        index += 2 if after[2] else 1
    return line


def rasterize(font, code, size):
    glyph = font.cmap.get(code, 0)
    scale = size / font.units
    advance = font.advance(glyph) * scale
    lines = [[(x * scale, -y * scale) for x, y in flatten(points)] for points in font.contours(glyph)]
    edges = []
    for line in lines:
        for (x0, y0), (x1, y1) in zip(line, line[1:] + line[:1]):
            if y0 != y1:
                edges.append((x0, y0, x1, y1))
    if edges == []:
        return advance, 0, 0, 0, 0, []
    left = int(min(min(e[0], e[2]) for e in edges) // 1)
    right = int(-(-max(max(e[0], e[2]) for e in edges) // 1))
    top = int(min(min(e[1], e[3]) for e in edges) // 1)
    bottom = int(-(-max(max(e[1], e[3]) for e in edges) // 1))
    width, height = right - left, bottom - top
    cover = [[0.0] * width for _ in range(height)]
    for row in range(height):
        for sample in range(ROWS):
            y = top + row + (sample + 0.5) / ROWS
            crossings = []
            for x0, y0, x1, y1 in edges:
                if (y0 <= y < y1) or (y1 <= y < y0):
                    crossings.append((x0 + (y - y0) * (x1 - x0) / (y1 - y0), 1 if y1 > y0 else -1))
            crossings.sort()
            winding = 0
            for (x, direction), (next_x, _) in zip(crossings, crossings[1:]):
                winding += direction
                if winding == 0:
                    continue
                a, b = x - left, next_x - left
                for column in range(max(0, int(a)), min(width, int(-(-b // 1)))):
                    span = min(b, column + 1) - max(a, column)
                    if span > 0:
                        cover[row][column] += span / ROWS
    pixels = [min(LEVELS, round(value * LEVELS)) for line in cover for value in line]
    return advance, left, top, width, height, pixels


def write_preview(path, glyphs, size, text):
    height = size * 2
    pen, placed = 4.0, []
    for char in text:
        advance, left, top, width, w_height, pixels = glyphs[ord(char)]
        placed.append((int(round(pen)) + left, size + top, width, w_height, pixels))
        pen += advance
    width = int(pen) + 8
    image = [[255] * width for _ in range(height)]
    for x0, y0, w, h, pixels in placed:
        for row in range(h):
            for column in range(w):
                level = pixels[row * w + column]
                if 0 <= y0 + row < height and 0 <= x0 + column < width:
                    image[y0 + row][x0 + column] = 255 - level * 231 // LEVELS
    raw = b"".join(b"\x00" + bytes(line) for line in image)
    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 0, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")
    Path(path).write_bytes(png)


arguments = [a for a in sys.argv[1:] if a.startswith("--") == False]
preview = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
if preview in arguments:
    arguments.remove(preview)
font_path = arguments[0] if arguments else subprocess.run(["fc-match", "Noto Sans", "file"], capture_output=True, text=True).stdout.strip().removeprefix(":file=").replace("\\", "")
size = int(arguments[1]) if len(arguments) > 1 else 14
font = Font(font_path)
print(f"sans: шрифт {Path(font_path).name}, {font.units} единиц на кегль, размер {size} px", flush=True)
glyphs = {}
for code in codes():
    glyphs[code] = rasterize(font, code, size)
print(f"sans: растеризовано {len(glyphs)} глифов", flush=True)
if preview:
    write_preview(preview, glyphs, size, "Сохранить Отмена Подробнее Удалить — Saltic 0123 «кнопка»")
    print(f"sans: образец {preview}", flush=True)
    sys.exit(0)
ascent = round(font.ascent * size / font.units)
lines = [f"SIZE = {size}", f"ASCENT = {ascent}", f"LINE = {round((font.ascent - font.descent) * size / font.units)}", ""]
fields = {"ADVANCE": [], "LEFT": [], "TOP": [], "WIDTH": [], "HEIGHT": [], "PIXELS": []}
for code in codes():
    advance, left, top, width, height, pixels = glyphs[code]
    fields["ADVANCE"].append(str(round(advance * 16)))
    fields["LEFT"].append(str(left))
    fields["TOP"].append(str(top))
    fields["WIDTH"].append(str(width))
    fields["HEIGHT"].append(str(height))
    fields["PIXELS"].append('"' + "".join(f"{level:x}" for level in pixels) + '"')
for name, values in fields.items():
    if name == "PIXELS":
        lines.append(f"{name} = [\n" + ",\n".join("    " + value for value in values) + "\n]")
    else:
        lines.append(f"{name} = [" + ", ".join(values) + "]")
TARGET.write_text("\n".join(lines) + "\n")
print(f"sans: записано {TARGET.relative_to(ROOT)}, {TARGET.stat().st_size} байт", flush=True)
