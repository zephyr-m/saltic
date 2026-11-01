"""Вшить JTML в модули Saltic: страница.jtml → generated/страница_jtml.saltic с константой JTML.

    python3 os/uiengine/tools/bake.py путь/app.jtml [ещё.jtml …] [--into папка/generated]
Без --into пишет в generated/ рядом с файлом. Программа: `use путь.generated.app_jtml`,
затем `uiengine.show(app_jtml.JTML)`.
"""
import sys
from pathlib import Path

arguments = sys.argv[1:]
into = None
if "--into" in arguments:
    into = Path(arguments[arguments.index("--into") + 1])
    arguments = arguments[:arguments.index("--into")] + arguments[arguments.index("--into") + 2:]
if arguments == []:
    sys.exit(__doc__)
for name in arguments:
    source = Path(name)
    text = source.read_text()
    escaped = text.replace("\\", "\\\\").replace('"', '\\"').replace("{", "\\{").replace("}", "\\}").replace("\n", "\\n")
    folder = into if into else source.parent / "generated"
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / (source.stem + "_jtml.saltic")
    target.write_text(f'JTML = "{escaped}"\n')
    print(f"bake: {source} → {target}, {len(text)} байт JTML", flush=True)
