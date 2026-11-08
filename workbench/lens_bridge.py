"""MCP-мост к lens: Saltic смотрит на свой код, агент спрашивает через MCP.

Запускается Claude Code по stdio (.mcp.json в корне репозитория). Работу
делает программа на Saltic workbench/lens.saltic (собирается компилятором с
полки bootstrap/saltic в .cache/build/workbench/lens, заново — если её нет
или исходник новее); мост только передаёт вызовы. Python — потому что MCP
говорит строками JSON через stdin, а Saltic пока читает с клавиатуры лишь по
клавише (io.key).

Инструменты:
  saltic_check — проверить файл (file) или кусок кода (code) без сборки
  saltic_api   — публичное лицо модуля: шапка и верхний уровень
  saltic_find  — где определено имя и где встречается
  saltic_build — собрать файл под цель, ошибки — списком
"""

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPILER = ROOT / "bootstrap" / "saltic"
SOURCE = ROOT / "workbench" / "lens.saltic"
WORK = ROOT / ".cache" / "build" / "workbench"
LENS = WORK / "lens"
SNIPPET = WORK / "lens-snippet.saltic"
LENS_HEAP = "1073741824"
BUILD_HEAP = "67108864"
TARGETS = ["x86_64", "x86_64-uefi", "rv64", "rv32i"]

TOOLS = {
    "saltic_check": (
        "Проверить Saltic без сборки (разбор и чекер, числа 61-битные): file — путь от корня репозитория или code — текст программы. Ответ: «ok» или строки «код|строка|столбец|текст».",
        {"type": "object", "properties": {"file": {"type": "string"}, "code": {"type": "string"}}},
    ),
    "saltic_api": (
        "Публичное лицо модуля: шапка (по канону в ней описан модуль) и все skill, Box и константы верхнего уровня. module — путь к файлу или имя через точки (core.group, os.target.uefi_x86_64.screen.graphics).",
        {"type": "object", "properties": {"module": {"type": "string"}}, "required": ["module"]},
    ),
    "saltic_find": (
        "Где определено имя (skill, Box, константа) и где встречается вызовом или полем, по *.saltic из git (кроме .archive).",
        {"type": "object", "properties": {"name": {"type": "string"}}, "required": ["name"]},
    ),
    "saltic_build": (
        "Собрать файл компилятором с полки: target — x86_64, x86_64-uefi, rv64, rv32i; output — куда (по умолчанию .cache/build/lens/<имя>); heap — куча в байтах. Ответ: путь собранного или ошибки списком.",
        {"type": "object", "properties": {"file": {"type": "string"}, "target": {"type": "string"}, "output": {"type": "string"}, "heap": {"type": "string"}}, "required": ["file", "target"]},
    ),
}


def log(text):
    print(f"lens_bridge: {text}", file=sys.stderr, flush=True)


def run(command, timeout=300):
    done = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=timeout)
    return done.returncode, done.stdout + done.stderr


def problems(output):
    lines = []
    for line in output.splitlines():
        parts = line.split("|", 3)
        if len(parts) == 4 and parts[1].isdigit():
            lines.append(f"{parts[3]} — {parts[0]}, строка {parts[1]}, столбец {parts[2]}")
    return lines


def ensure_lens():
    if LENS.exists() and LENS.stat().st_mtime >= SOURCE.stat().st_mtime:
        return None
    WORK.mkdir(parents=True, exist_ok=True)
    log("собираю lens")
    part = WORK / "lens.part"
    code, output = run([str(COMPILER), str(SOURCE), str(part), LENS_HEAP, "x86_64"])
    if code != 0:
        return "lens не собрался:\n" + "\n".join(problems(output) or [output])
    part.chmod(0o755)
    part.replace(LENS)
    return None


def lens(*args):
    broken = ensure_lens()
    if broken:
        return broken, True
    code, output = run([str(LENS), *args], timeout=120)
    return output.strip(), code != 0


def check(args):
    target = args.get("file")
    if args.get("code"):
        WORK.mkdir(parents=True, exist_ok=True)
        SNIPPET.write_text(args["code"])
        target = str(SNIPPET.relative_to(ROOT))
    if not target:
        return "нужен file или code", True
    text, failed = lens("check", target)
    return text, failed or text != "ok"


def build(args):
    target = args["target"]
    if target not in TARGETS:
        return f"цель — одна из {', '.join(TARGETS)}", True
    source = args["file"]
    name = Path(source).stem + (".efi" if target == "x86_64-uefi" else "")
    output = Path(args.get("output") or (ROOT / ".cache" / "build" / "lens" / name))
    if not output.is_absolute():
        output = ROOT / output
    output.parent.mkdir(parents=True, exist_ok=True)
    part = output.with_name(output.name + ".part")
    code, text = run([str(COMPILER), source, str(part), args.get("heap") or BUILD_HEAP, target])
    if code != 0:
        found = problems(text)
        tail = [line for line in text.splitlines() if not line.startswith("toolchain:")]
        return "сборка не прошла:\n" + "\n".join(found or tail), True
    part.chmod(0o755)
    part.replace(output)
    return f"собрано: {output} ({output.stat().st_size} байт)", False


def call(name, args):
    if name == "saltic_check":
        return check(args)
    if name == "saltic_api":
        return lens("api", args["module"])
    if name == "saltic_find":
        return lens("find", args["name"])
    if name == "saltic_build":
        return build(args)
    return f"нет инструмента {name}", True


def handle(message):
    method = message.get("method")
    if method == "initialize":
        version = message.get("params", {}).get("protocolVersion", "2025-06-18")
        return {"protocolVersion": version, "capabilities": {"tools": {}}, "serverInfo": {"name": "saltic-lens", "version": "1.0"}}
    if method == "ping":
        return {}
    if method == "tools/list":
        return {"tools": [{"name": name, "description": about, "inputSchema": shape} for name, (about, shape) in TOOLS.items()]}
    if method == "tools/call":
        name = message["params"]["name"]
        args = message["params"].get("arguments") or {}
        try:
            text, failed = call(name, args)
        except (OSError, subprocess.TimeoutExpired) as err:
            text, failed = f"не вышло: {err}", True
        return {"content": [{"type": "text", "text": text}], "isError": failed}
    return None


def main():
    for line in sys.stdin:
        if not line.strip():
            continue
        message = json.loads(line)
        if "id" not in message:
            continue
        result = handle(message)
        if result is None:
            answer = {"jsonrpc": "2.0", "id": message["id"], "error": {"code": -32601, "message": f"нет метода {message.get('method')}"}}
        else:
            answer = {"jsonrpc": "2.0", "id": message["id"], "result": result}
        sys.stdout.write(json.dumps(answer, ensure_ascii=False) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
