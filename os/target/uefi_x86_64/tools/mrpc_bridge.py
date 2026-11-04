"""MCP-мост к агенту Acer: команды mRPC/1.0 агента как инструменты MCP.

Запускается Claude Code по stdio (.mcp.json в корне репозитория). На старте
спрашивает у агента help и describe и превращает каждую команду реестра
в инструмент acer_<имя>. Сверх реестра:
  acer_run     — запустить принятое, не дожидаясь конца программы
  acer_call    — любой cmd с параметрами (если агента не было на старте)
  acer_quit    — выйти из запущенной программы (её сеть понимает mRPC quit)
  acer_upload  — залить .efi (tools/upload.py), по желанию запустить
  acer_shot    — снимок экрана (tools/shot.py), отдаётся картинкой
  acer_snippet — собрать и запустить кусок Saltic (tools/snippet.py)
Транспорт к агенту — UDP 10.0.0.2:5555, одна датаграмма — один JSON.
"""

import base64
import json
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

AGENT = ("10.0.0.2", 5555)
LOCAL = "10.0.0.1"
TOOLS = Path(__file__).resolve().parent
PREFIX = "acer_"
counter = 0


def log(text):
    print(f"mrpc_bridge: {text}", file=sys.stderr, flush=True)


def ask(cmd, params=None, timeout=8):
    global counter
    counter += 1
    request = {"cmd": cmd, "id": counter, **(params or {})}
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.bind((LOCAL, 0))
        sock.settimeout(timeout)
        sock.sendto(json.dumps(request, ensure_ascii=False).encode(), AGENT)
        started = time.time()
        while True:
            data, _ = sock.recvfrom(65535)
            try:
                reply = json.loads(data)
            except ValueError:
                return {"ok": True, "cmd": cmd, "data": {"text": data.decode(errors="replace")}, "note": "ответ не mRPC (текст программы)"}
            if reply.get("id", counter) == counter:
                return reply
            if time.time() - started > timeout:
                raise socket.timeout()
    finally:
        sock.close()


def fire(text):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((LOCAL, 0))
    sock.sendto(text.encode(), AGENT)
    sock.close()


def reply_text(reply):
    if reply.get("ok"):
        data = reply.get("data", {})
        if isinstance(data, dict) and set(data) <= {"text", "cut"}:
            text = data.get("text", "")
            return text + ("\n[ответ обрезан до одной датаграммы]" if data.get("cut") else "")
        return json.dumps(data, ensure_ascii=False, indent=1)
    error = reply.get("error", {})
    text = f"{error.get('code')}: {error.get('message')}"
    if "commands" in reply:
        text += "\nкоманды: " + ", ".join(reply["commands"])
    return text


def registry():
    commands, start = {}, 0
    try:
        while start is not None:
            page = ask("help", {"from": start}, timeout=3).get("data", {})
            commands.update(page.get("commands", {}))
            start = page.get("next")
    except OSError as err:
        log(f"агент молчит ({err}) — только общие инструменты")
    log(f"от агента {len(commands)} команд")
    return commands


def schema(entry):
    properties = {}
    for name in entry.get("params", []):
        properties[name] = {"type": ["string", "number"]}
    for name in entry.get("options", {}):
        properties[name] = {"type": ["string", "number"]}
    return {"type": "object", "properties": properties, "required": list(entry.get("params", []))}


EXTRA = {
    "call": ("Любая команда агента mRPC: cmd и параметры.", {"type": "object", "properties": {"cmd": {"type": "string"}, "params": {"type": "object"}}, "required": ["cmd"]}),
    "run": ("Запустить принятую программу; ответ агента придёт, только когда она закончит, поэтому не ждём.", {"type": "object", "properties": {}}),
    "quit": ("Выйти из запущенной программы на главный экран агента (программы с сетью понимают quit).", {"type": "object", "properties": {}}),
    "upload": ("Залить .efi на агента; run = true — сразу запустить (ответ не ждём).", {"type": "object", "properties": {"path": {"type": "string"}, "run": {"type": "boolean"}}, "required": ["path"]}),
    "shot": ("Снимок экрана Acer: картинка PNG; path — куда ещё сохранить.", {"type": "object", "properties": {"path": {"type": "string"}}}),
    "snippet": ("Собрать и запустить кусок Saltic на Acer (тело skill snippet() или файл целиком через file).", {"type": "object", "properties": {"code": {"type": "string"}, "file": {"type": "string"}}}),
}


def run_tool(command, args, timeout):
    done = subprocess.run([sys.executable, str(TOOLS / command)] + args, capture_output=True, text=True, timeout=timeout)
    return (done.stdout + done.stderr).strip(), done.returncode != 0


def call_extra(name, args):
    if name == "call":
        return reply_text(ask(args["cmd"], args.get("params"))), False
    if name == "run":
        fire("run")
        return "run отправлен; ответ придёт, когда программа закончит", False
    if name == "quit":
        return reply_text(ask("quit")), False
    if name == "upload":
        text, failed = run_tool("upload.py", [args["path"]], 300)
        if failed or args.get("run") is not True:
            return text, failed
        fire("run")
        return text + "\nrun отправлен; ответ придёт, когда программа закончит", False
    if name == "shot":
        path = args.get("path") or tempfile.mktemp(suffix=".png", prefix="acer-shot-")
        text, failed = run_tool("shot.py", [path], 60)
        if failed:
            return text, True
        image = base64.b64encode(Path(path).read_bytes()).decode()
        return [{"type": "text", "text": f"{text}\nсохранён: {path}"}, {"type": "image", "data": image, "mimeType": "image/png"}], False
    if name == "snippet":
        if "file" in args:
            return run_tool("snippet.py", ["-f", args["file"]], 300)
        return run_tool("snippet.py", [args.get("code", "")], 300)
    return f"нет инструмента {name}", True


def handle(message, commands):
    method = message.get("method")
    if method == "initialize":
        version = message.get("params", {}).get("protocolVersion", "2025-06-18")
        return {"protocolVersion": version, "capabilities": {"tools": {}}, "serverInfo": {"name": "acer-mrpc", "version": "1.0"}}
    if method == "ping":
        return {}
    if method == "tools/list":
        tools = [{"name": PREFIX + name.replace("-", "_"), "description": f"[{entry.get('type')}] {entry.get('description', '')}", "inputSchema": schema(entry)} for name, entry in commands.items() if name not in EXTRA]
        tools += [{"name": PREFIX + name, "description": about, "inputSchema": shape} for name, (about, shape) in EXTRA.items()]
        return {"tools": tools}
    if method == "tools/call":
        name = message["params"]["name"][len(PREFIX):]
        args = message["params"].get("arguments") or {}
        try:
            if name in EXTRA:
                content, failed = call_extra(name, args)
            else:
                cmd = next((key for key in commands if key.replace("-", "_") == name), name)
                reply = ask(cmd, args, timeout=30 if cmd in ("volumes", "install", "keep", "usb", "pci") else 8)
                content, failed = reply_text(reply), reply.get("ok") is not True
        except (OSError, subprocess.TimeoutExpired) as err:
            content, failed = f"агент не ответил: {err}", True
        if isinstance(content, str):
            content = [{"type": "text", "text": content}]
        return {"content": content, "isError": failed}
    return None


def main():
    commands = registry()
    for line in sys.stdin:
        if not line.strip():
            continue
        message = json.loads(line)
        if "id" not in message:
            continue
        result = handle(message, commands)
        if result is None:
            answer = {"jsonrpc": "2.0", "id": message["id"], "error": {"code": -32601, "message": f"нет метода {message.get('method')}"}}
        else:
            answer = {"jsonrpc": "2.0", "id": message["id"], "result": result}
        sys.stdout.write(json.dumps(answer, ensure_ascii=False) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
