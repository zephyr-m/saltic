import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
SOURCE = ROOT / "os/fonts/spleen.saltic"
TARGET = ROOT / "os/target/uefi_x86_64/glyphs.saltic"
SIZES = [("8X16", 8, 16), ("12X24", 12, 24), ("16X32", 16, 32)]

text = SOURCE.read_text()


def table(name):
    start = text.index(f"GLYPHS_{name} = [")
    depth, index = 0, text.index("[", start)
    begin = index
    while True:
        depth += {"[": 1, "]": -1}.get(text[index], 0)
        index += 1
        if depth == 0:
            break
    body = text[begin + 1:index - 1]
    return [[int(x) for x in re.findall(r"\d+", glyph)] for glyph in re.findall(r"\[([^\[\]]*)\]", body)]


lines = []
for name, width, height in SIZES:
    glyphs = table(name)
    print(f"glyphs: {name} — {len(glyphs)} букв", flush=True)
    lines.append(f"GLYPHS_{name} = [")
    rows = []
    for glyph in glyphs:
        assert len(glyph) == height, (name, len(glyph))
        rows.append('    "' + "".join(f"{row:04x}" for row in glyph) + '"')
    lines.append(",\n".join(rows))
    lines.append("]")
    lines.append("")
TARGET.write_text("\n".join(lines))
print(f"glyphs: записано {TARGET.relative_to(ROOT)}, {TARGET.stat().st_size} байт", flush=True)
