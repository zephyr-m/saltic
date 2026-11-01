"""Сглаженные начертания UIEngine: растеризует TrueType в полутона и пишет fonts/generated/.

Свой растеризатор, без библиотек: контуры glyf → отрезки → покрытие пикселя
(8 строк проб по вертикали, точная площадь по горизонтали) → 16 уровней.
    python3 os/uiengine/tools/fonts.py                 — все начертания из FACES
    python3 os/uiengine/tools/fonts.py 14 --weight 600 --preview out.png — образец
Шрифт — Noto Sans через fc-match (вариативный: жирность из gvar).
"""
import struct
import subprocess
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TARGET = ROOT / "os/uiengine/fonts/generated"
SANS = "Noto Sans"
MONO = "Noto Sans Mono"
FACES = [("regular14", SANS, 14, 400), ("medium14", SANS, 14, 500), ("semibold14", SANS, 14, 600), ("regular12", SANS, 12, 400), ("semibold18", SANS, 18, 600), ("mono13", MONO, 13, 400)]
ROWS = 8
LEVELS = 15
EXTRA = [0x2014, 0x2013, 0x00AB, 0x00BB, 0x00D7, 0x2026, 0x00B0, 0x2116, 0x2190, 0x2191, 0x2192, 0x2193, 0x2194]


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
        self.coords = []

    def set_weight(self, weight):
        """Нормализованные координаты осей (fvar + avar) для жирности weight."""
        fvar = self.table("fvar")
        axes_at, _, count, size = struct.unpack(">HHHH", fvar[4:12])
        maps = self.avar_maps(count)
        self.coords = []
        for axis in range(count):
            record = fvar[axes_at + axis * size:axes_at + axis * size + 20]
            tag = record[0:4].decode()
            low, default, high = (v / 65536 for v in struct.unpack(">iii", record[4:16]))
            value = min(high, max(low, weight)) if tag == "wght" else default
            if value < default:
                normal = (value - default) / (default - low)
            elif value > default:
                normal = (value - default) / (high - default)
            else:
                normal = 0.0
            self.coords.append(piecewise(maps[axis], normal) if maps else normal)

    def avar_maps(self, count):
        if "avar" not in self.tables:
            return []
        avar = self.table("avar")
        at, maps = 8, []
        for _ in range(count):
            pairs = struct.unpack(">H", avar[at:at + 2])[0]
            values = struct.unpack(f">{pairs * 2}h", avar[at + 2:at + 2 + pairs * 4])
            maps.append([(values[i] / 16384, values[i + 1] / 16384) for i in range(0, len(values), 2)])
            at += 2 + pairs * 4
        return maps

    def deltas(self, glyph, total, ends):
        """Смещения точек (включая 4 фантомные) из gvar для текущих координат."""
        result = [[0.0, 0.0] for _ in range(total + 4)]
        if self.coords == [] or "gvar" not in self.tables:
            return result
        gvar = self.table("gvar")
        axes, shared_count, shared_at, _, flags, array_at = struct.unpack(">HHIHHI", gvar[4:20])
        if flags & 1:
            start, end = struct.unpack(">II", gvar[20 + glyph * 4:28 + glyph * 4])
        else:
            start, end = (v * 2 for v in struct.unpack(">HH", gvar[20 + glyph * 2:24 + glyph * 2]))
        if start == end:
            return result
        data = gvar[array_at + start:array_at + end]
        shared = [struct.unpack(f">{axes}h", gvar[shared_at + i * axes * 2:shared_at + (i + 1) * axes * 2]) for i in range(shared_count)]
        count, serial_at = struct.unpack(">HH", data[0:4])
        at, headers = 4, []
        for _ in range(count & 0x0FFF):
            size, index = struct.unpack(">HH", data[at:at + 4])
            at += 4
            if index & 0x8000:
                peak = struct.unpack(f">{axes}h", data[at:at + axes * 2])
                at += axes * 2
            else:
                peak = shared[index & 0x0FFF]
            region = None
            if index & 0x4000:
                region = (struct.unpack(f">{axes}h", data[at:at + axes * 2]), struct.unpack(f">{axes}h", data[at + axes * 2:at + axes * 4]))
                at += axes * 4
            headers.append((size, index, peak, region))
        serial = serial_at
        shared_points = None
        if count & 0x8000:
            shared_points, serial = read_points(data, serial)
        for size, index, peak, region in headers:
            chunk_end = serial + size
            weight = tuple_scalar(self.coords, peak, region)
            points, at = (read_points(data, serial) if index & 0x2000 else (shared_points, serial))
            if weight != 0.0:
                every = points is None
                touched = list(range(total + 4)) if every else points
                xs, at = read_deltas(data, at, len(touched))
                ys, at = read_deltas(data, at, len(touched))
                moved = {point: (x, y) for point, x, y in zip(touched, xs, ys)}
                if every == False and ends is not None:
                    moved = interpolate(moved, self.original, ends)
                for point, (x, y) in moved.items():
                    if point < len(result):
                        result[point][0] += x * weight
                        result[point][1] += y * weight
            serial = chunk_end
        return result

    def advance_of(self, glyph):
        base = self.advance(glyph)
        if self.coords == []:
            return base
        self.original = []
        total = self.point_count(glyph)
        moved = self.deltas(glyph, total, None)
        return base + moved[total + 1][0] - moved[total][0]

    def point_count(self, glyph):
        data = self.glyph_bytes(glyph)
        if data == b"":
            return 0
        count = struct.unpack(">h", data[0:2])[0]
        if count >= 0:
            return struct.unpack(">H", data[10 + count * 2 - 2:10 + count * 2])[0] + 1 if count else 0
        at, components = 10, 0
        while True:
            flags = struct.unpack(">H", data[at:at + 2])[0]
            at += 4 + (4 if flags & 1 else 2) + (2 if flags & 8 else 4 if flags & 0x40 else 8 if flags & 0x80 else 0)
            components += 1
            if flags & 0x20 == 0:
                return components

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
            return self.composite(data, dx, dy, glyph)
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
        self.original = list(zip(xs, ys))
        moved = self.deltas(glyph, total, ends)
        xs = [x + moved[i][0] for i, x in enumerate(xs)]
        ys = [y + moved[i][1] for i, y in enumerate(ys)]
        a, b, c, d = scale
        result, first = [], 0
        for end in ends:
            points = [(xs[i] * a + ys[i] * c + dx, xs[i] * b + ys[i] * d + dy, flags[i] & 1) for i in range(first, end + 1)]
            result.append(points)
            first = end + 1
        return result

    def composite(self, data, dx, dy, glyph):
        self.original = []
        moved = self.deltas(glyph, self.point_count(glyph), None)
        at, result, component = 10, [], 0
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
            if flags & 2:
                arg1 += moved[component][0]
                arg2 += moved[component][1]
            component += 1
            result += self.contours(glyph, dx + arg1, dy + arg2, scale)
            if flags & 0x20 == 0:
                return result


def piecewise(pairs, value):
    for (x0, y0), (x1, y1) in zip(pairs, pairs[1:]):
        if x0 <= value <= x1:
            return y0 if x1 == x0 else y0 + (value - x0) * (y1 - y0) / (x1 - x0)
    return value


def tuple_scalar(coords, peak, region):
    scalar = 1.0
    for axis, value in enumerate(coords):
        top = peak[axis] / 16384
        if top == 0:
            continue
        if value == 0:
            return 0.0
        if region:
            low, high = region[0][axis] / 16384, region[1][axis] / 16384
            if value < low or value > high:
                return 0.0
            scalar *= (value - low) / (top - low) if value < top else (high - value) / (high - top) if value > top else 1.0
        else:
            if value < min(0, top) or value > max(0, top):
                return 0.0
            scalar *= value / top
    return scalar


def read_points(data, at):
    count = data[at]
    at += 1
    if count == 0:
        return None, at
    if count & 0x80:
        count = ((count & 0x7F) << 8) | data[at]
        at += 1
    points, value = [], 0
    while len(points) < count:
        control = data[at]
        at += 1
        run = (control & 0x7F) + 1
        for _ in range(run):
            if control & 0x80:
                value += struct.unpack(">H", data[at:at + 2])[0]
                at += 2
            else:
                value += data[at]
                at += 1
            points.append(value)
    return points, at


def read_deltas(data, at, count):
    values = []
    while len(values) < count:
        control = data[at]
        at += 1
        run = (control & 0x3F) + 1
        if control & 0x80:
            values += [0] * run
        elif control & 0x40:
            values += list(struct.unpack(f">{run}h", data[at:at + run * 2]))
            at += run * 2
        else:
            values += list(struct.unpack(f">{run}b", data[at:at + run]))
            at += run
    return values, at


def interpolate(moved, original, ends):
    """IUP: нетронутые точки контура получают смещение от соседей."""
    result = dict(moved)
    first = 0
    for end in ends:
        contour = list(range(first, end + 1))
        touched = [p for p in contour if p in moved]
        first = end + 1
        if touched == [] or len(touched) == len(contour):
            continue
        for point in contour:
            if point in moved:
                continue
            before = max([p for p in touched if p < point], default=touched[-1])
            after = min([p for p in touched if p > point], default=touched[0])
            shift = []
            for axis in (0, 1):
                c, c1, c2 = original[point][axis], original[before][axis], original[after][axis]
                d1, d2 = moved[before][axis], moved[after][axis]
                if c1 == c2:
                    shift.append(d1 if d1 == d2 else 0.0)
                    continue
                if c1 > c2:
                    c1, c2, d1, d2 = c2, c1, d2, d1
                if c <= c1:
                    shift.append(d1)
                elif c >= c2:
                    shift.append(d2)
                else:
                    shift.append(d1 + (c - c1) * (d2 - d1) / (c2 - c1))
            result[point] = tuple(shift)
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
    advance = font.advance_of(glyph) * scale
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


def option(name, fallback):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else fallback


preview = option("--preview", None)
weight = int(option("--weight", "400"))
skipped = {preview, str(weight)}
words = [a for a in sys.argv[1:] if a.startswith("--") == False and a not in skipped]
size = next((int(a) for a in words if a.isdigit()), 14)
fonts = [a for a in words if a.isdigit() == False]


def family_path(family):
    return subprocess.run(["fc-match", family, "file"], capture_output=True, text=True).stdout.strip().removeprefix(":file=").replace("\\", "")


font = Font(fonts[0] if fonts else family_path(SANS))
loaded = {}


def face(size, weight):
    font.set_weight(weight)
    return {code: rasterize(font, code, size) for code in codes()}


if preview:
    write_preview(preview, face(size, weight), size, "Сохранить Отмена Подробнее Удалить — Saltic 0123 «кнопка»")
    print(f"fonts: образец {preview}", flush=True)
    sys.exit(0)
for name, family, face_size, face_weight in FACES:
    if family not in loaded:
        loaded[family] = Font(family_path(family))
        print(f"fonts: шрифт {family} — {Path(family_path(family)).name}", flush=True)
    font = loaded[family]
    glyphs = face(face_size, face_weight)
    ascent = round(font.ascent * face_size / font.units)
    line = round((font.ascent - font.descent) * face_size / font.units)
    lines = [f"ASCENT = {ascent}", f"LINE = {line}", ""]
    fields = {"ADVANCE": [], "LEFT": [], "TOP": [], "WIDTH": [], "HEIGHT": [], "PIXELS": []}
    for code in codes():
        advance, left, top, width, height, pixels = glyphs[code]
        fields["ADVANCE"].append(str(round(advance * 16)))
        fields["LEFT"].append(str(left))
        fields["TOP"].append(str(top))
        fields["WIDTH"].append(str(width))
        fields["HEIGHT"].append(str(height))
        fields["PIXELS"].append('"' + "".join(f"{level:x}" for level in pixels) + '"')
    for field, values in fields.items():
        if field == "PIXELS":
            lines.append(f"{field} = [\n" + ",\n".join("    " + value for value in values) + "\n]")
        else:
            lines.append(f"{field} = [" + ", ".join(values) + "]")
    target = TARGET / f"{name}.saltic"
    target.write_text("\n".join(lines) + "\n")
    print(f"fonts: {name} — {face_size} px, жирность {face_weight}, {target.stat().st_size} байт", flush=True)
