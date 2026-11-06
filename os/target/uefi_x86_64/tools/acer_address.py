"""Где агент Acer: кабель или Wi-Fi.

route() -> (наш адрес, адрес агента). Сначала кабель: 10.0.0.1 → 10.0.0.2,
если у интерфейса с 10.0.0.1 есть линк (carrier) — без лишних команд агенту.
Иначе Wi-Fi (интерфейсы wl*): сперва последний известный адрес агента
(MEMORY), затем "time" прямо на каждый адрес подсети /24 — первый ответивший
и есть агент. Широковещание не годится: ответ на него приходит с адреса, на
который мы не писали, и брандмауэр компьютера его режет. Первый пакет после
тишины в Wi-Fi часто теряется, поэтому попыток TRIES.
SALTIC_ACER="наш,агент" — задать путь руками.
Снимок экрана (shot) и чат ходят только по кабелю.
"""

import os
import socket
import subprocess
import sys
import time
from pathlib import Path

PORT = 5555
TRIES = 3
WAIT = 1.0
CABLE = ("10.0.0.1", "10.0.0.2")
MEMORY = Path.home() / ".cache" / "saltic" / "acer-wifi"


def ask_time(local, targets):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.bind((local, 0))
        sock.settimeout(WAIT)
        for _ in range(TRIES):
            for target in targets:
                try:
                    sock.sendto(b"time", (target, PORT))
                except OSError:
                    continue
            deadline = time.time() + WAIT
            while time.time() < deadline:
                try:
                    return sock.recvfrom(4096)[1][0]
                except socket.timeout:
                    break
                except ConnectionRefusedError:
                    continue
        return None
    except OSError:
        return None
    finally:
        sock.close()


def addresses():
    shown = subprocess.run(["ip", "-4", "-o", "addr"], capture_output=True, text=True).stdout
    return [(parts[1], parts[3].split("/")[0]) for parts in map(str.split, shown.splitlines()) if len(parts) > 3]


def cable_up():
    for name, address in addresses():
        if address == CABLE[0]:
            try:
                return open(f"/sys/class/net/{name}/carrier").read().strip() == "1"
            except OSError:
                return False
    return False


def remembered():
    try:
        return MEMORY.read_text().strip()
    except OSError:
        return ""


def remember(agent):
    MEMORY.parent.mkdir(parents=True, exist_ok=True)
    MEMORY.write_text(agent + "\n")


def neighbours(local):
    prefix = local.rsplit(".", 1)[0]
    return [f"{prefix}.{last}" for last in range(1, 255) if f"{prefix}.{last}" != local]


def route(say=True):
    given = os.environ.get("SALTIC_ACER")
    if given:
        local, agent = given.split(",")
        return local, agent
    if cable_up():
        return CABLE
    last = remembered()
    for name, local in addresses():
        if name.startswith("wl") == False:
            continue
        agent = None
        if last.rsplit(".", 1)[0] == local.rsplit(".", 1)[0]:
            agent = ask_time(local, [last])
        if agent is None:
            if say:
                print(f"acer: ищу агента в сети {local}/24 ...", file=sys.stderr)
            agent = ask_time(local, neighbours(local))
        if agent:
            remember(agent)
            if say:
                print(f"acer: кабеля нет, агент по Wi-Fi: {agent} (с {local})", file=sys.stderr)
            return local, agent
    if say:
        print("acer: агент не отвечает ни по кабелю, ни по Wi-Fi — беру кабель", file=sys.stderr)
    return CABLE


if __name__ == "__main__":
    print("%s -> %s" % route())
