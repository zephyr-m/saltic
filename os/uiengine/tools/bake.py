"""Вшить JTML в модуль Saltic: app.jtml → generated/app_jtml.saltic с константой JTML.

    python3 os/uiengine/tools/bake.py путь/app.jtml
Программа: `use путь.generated.app_jtml`, затем `uiengine.show(app_jtml.JTML)`.
"""
import sys
from pathlib import Path

if len(sys.argv) != 2:
    sys.exit(__doc__)
source = Path(sys.argv[1])
text = source.read_text()
escaped = text.replace("\\", "\\\\").replace('"', '\\"').replace("{", "\\{").replace("}", "\\}").replace("\n", "\\n")
target = source.parent / "generated" / (source.stem + "_jtml.saltic")
target.parent.mkdir(exist_ok=True)
target.write_text(f'JTML = "{escaped}"\n')
print(f"bake: {source} → {target}, {len(text)} байт JTML", flush=True)
