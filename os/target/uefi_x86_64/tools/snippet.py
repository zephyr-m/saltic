"""Кусок Saltic на Acer: обернуть в программу, собрать, залить, запустить, показать ответ.

Кусок — тело навыка, который отдаёт текст через out:
    python3 tools/snippet.py 'out "привет с Acer"'
    python3 tools/snippet.py -f кусок.saltic
Строки `use …` в начале куска уходят наверх программы.
Компилятор — переменная SALTIC_COMPILER или полка bootstrap/.
"""
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
TOOLS = Path(__file__).resolve().parent
HEAP = "67108864"


def compiler():
    chosen = os.environ.get("SALTIC_COMPILER")
    if chosen:
        return chosen
    shelf = sorted(ROOT.glob("bootstrap/saltic-*-compiler-x86_64-linux"))
    if shelf == []:
        sys.exit("snippet: нет компилятора — задай SALTIC_COMPILER")
    return str(shelf[-1])


def program(snippet):
    uses, body = [], []
    for line in snippet.splitlines():
        (uses if line.startswith("use ") else body).append(line)
    head = ["use os.target.uefi_x86_64.reply"] + uses
    inner = "\n".join("    " + line for line in body)
    return "\n".join(head) + f"\n\nskill snippet() {{\n{inner}\n}}\n\nprogram() {{\n    @said = snippet() rescue |err| {{ \"ошибка куска: {{err}}\" }}\n    reply.finish(said)\n    out none\n}}\n"


if len(sys.argv) < 2:
    sys.exit(__doc__)
snippet = Path(sys.argv[2]).read_text() if sys.argv[1] == "-f" else " ".join(sys.argv[1:])
work = Path(tempfile.mkdtemp(prefix="snippet-"))
source, image = work / "snippet.saltic", work / "snippet.efi"
source.write_text(program(snippet))
print(f"snippet: собираю {source}", flush=True)
built = subprocess.run([compiler(), str(source), str(image), HEAP, "x86_64-uefi"], cwd=ROOT, capture_output=True, text=True)
if built.returncode != 0 or image.exists() == False:
    print(built.stdout + built.stderr, file=sys.stderr)
    sys.exit("snippet: не собралось")
print(f"snippet: собрано, {image.stat().st_size} байт; заливаю и запускаю", flush=True)
sent = subprocess.run([sys.executable, str(TOOLS / "upload.py"), str(image), "--run"], capture_output=True, text=True)
if sent.returncode != 0:
    print(sent.stdout + sent.stderr, file=sys.stderr)
    sys.exit("snippet: заливка не удалась")
answer = sent.stdout.split("upload: агент: программа", 1)
print("программа" + answer[1] if len(answer) == 2 else sent.stdout, end="")
