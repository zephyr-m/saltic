"""Кусок Saltic на Acer: обернуть в программу, собрать, залить, запустить, показать ответ.

Кусок — тело навыка, который отдаёт текст через out:
    python3 tools/snippet.py 'out "привет с Acer"'
    python3 tools/snippet.py -f кусок.saltic
Шапка `-- …` и строки `use …` уходят наверх программы. Кусок со своими
навыками объявляет `skill snippet()` сам — тогда он идёт в программу как есть.
Компилятор — переменная SALTIC_COMPILER или полка bootstrap/.
SNIPPET_DATA=файл — приложить данные: программа дополняется до 1 МБ, файл идёт
следом и остаётся в памяти агента; адрес — константы DATA_HI и DATA_LO.
"""
import os
import socket
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
TOOLS = Path(__file__).resolve().parent
HEAP = "67108864"
DATA_OFFSET = 1 << 20


def compiler():
    chosen = os.environ.get("SALTIC_COMPILER")
    if chosen:
        return chosen
    shelf = sorted(ROOT.glob("bootstrap/saltic-*-compiler-x86_64-linux"))
    if shelf == []:
        sys.exit("snippet: нет компилятора — задай SALTIC_COMPILER")
    return str(shelf[-1])


def bay_address(total):
    """Причал агента под заливку total байт: upload заранее даёт ему страницы
    нужного размера, upload.py потом получит те же."""
    asked = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    asked.settimeout(5)
    asked.bind(("10.0.0.1", 0))
    asked.sendto(f"upload {total}".encode(), ("10.0.0.2", 5555))
    asked.recvfrom(65535)
    asked.sendto(b"info", ("10.0.0.2", 5555))
    said = asked.recvfrom(65535)[0].decode(errors="replace")
    return int(said.split("приём программ ", 1)[1].split(",", 1)[0], 16)


def program(snippet, constants=""):
    header, uses, body = [], [], []
    for line in snippet.splitlines():
        if line.startswith("--") and body == [] and uses == []:
            header.append(line)
        else:
            (uses if line.startswith("use ") else body).append(line)
    head = header + ["use os.target.uefi_x86_64.network.reply"] + uses + ([constants] if constants else [])
    if any(line.startswith("skill snippet()") for line in body):
        inner = "\n".join(body)
        return "\n".join(head) + f"\n\n{inner}\n\nprogram() {{\n    @said = snippet() rescue |err| {{ \"ошибка куска: {{err}}\" }}\n    reply.finish(said)\n    out none\n}}\n"
    inner = "\n".join("    " + line for line in body)
    return "\n".join(head) + f"\n\nskill snippet() {{\n{inner}\n}}\n\nprogram() {{\n    @said = snippet() rescue |err| {{ \"ошибка куска: {{err}}\" }}\n    reply.finish(said)\n    out none\n}}\n"


if len(sys.argv) < 2:
    sys.exit(__doc__)
snippet = Path(sys.argv[2]).read_text() if sys.argv[1] == "-f" else " ".join(sys.argv[1:])
shown = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
shown.settimeout(5)
shown.bind(("10.0.0.1", 0))
# Код уходит одним кадром: длинный разлетается на куски, а у агента 4 места
# в кольце приёма — переполнение глушит приём карты насовсем.
shown_bytes = ("code " + snippet).encode()[:1400].decode(errors="ignore").encode()
shown.sendto(shown_bytes, ("10.0.0.2", 5555))
print(f"snippet: агент: {shown.recvfrom(65535)[0].decode(errors='replace')}", flush=True)
work = Path(tempfile.mkdtemp(prefix="snippet-"))
source, image = work / "snippet.saltic", work / "snippet.efi"
data = Path(os.environ["SNIPPET_DATA"]).read_bytes() if os.environ.get("SNIPPET_DATA") else b""
constants = ""
if data:
    at = bay_address(DATA_OFFSET + len(data)) + DATA_OFFSET
    constants = f"\nDATA_HI = {at >> 16}\nDATA_LO = {at & 0xffff}\nDATA_BYTES = {len(data)}"
    print(f"snippet: данные {len(data)} байт лягут по адресу {at:08x}", flush=True)
source.write_text(program(snippet, constants))
print(f"snippet: собираю {source}", flush=True)
built = subprocess.run([compiler(), str(source), str(image), HEAP, "x86_64-uefi"], cwd=ROOT, capture_output=True, text=True)
if built.returncode != 0 or image.exists() == False:
    print(built.stdout + built.stderr, file=sys.stderr)
    sys.exit("snippet: не собралось")
print(f"snippet: собрано, {image.stat().st_size} байт; заливаю и запускаю", flush=True)
if data:
    built_bytes = image.read_bytes()
    if len(built_bytes) > DATA_OFFSET:
        sys.exit("snippet: программа больше 1 МБ, данные некуда положить")
    image.write_bytes(built_bytes + bytes(DATA_OFFSET - len(built_bytes)) + data)
sent = subprocess.run([sys.executable, str(TOOLS / "upload.py"), str(image), "--run"], capture_output=True, text=True)
if sent.returncode != 0:
    print(sent.stdout + sent.stderr, file=sys.stderr)
    sys.exit("snippet: заливка не удалась")
answer = sent.stdout.split("upload: агент: программа", 1)
print("программа" + answer[1] if len(answer) == 2 else sent.stdout, end="")
