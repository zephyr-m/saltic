"""Чат с программой chat.saltic на Acer.

    python3 tools/chat.py listen [журнал]   — слушать сообщения с клавиатуры Acer (порт 5557);
                                             раз в 5 с стучится к Acer с этого же порта,
                                             чтобы файрвол пропускал ответы
    python3 tools/chat.py say <текст>       — отправить сообщение на экран Acer
"""
import socket
import sys
import time

AGENT = ("10.0.0.2", 5555)
HOST = ("10.0.0.1", 5557)

if len(sys.argv) < 2:
    sys.exit(__doc__)
if sys.argv[1] == "listen":
    log = open(sys.argv[2], "a", buffering=1) if len(sys.argv) > 2 else sys.stdout
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(HOST)
    sock.settimeout(5)
    print(f"chat: слушаю {HOST[0]}:{HOST[1]}", file=log, flush=True)
    while True:
        sock.sendto(b"knock", AGENT)
        try:
            data, _ = sock.recvfrom(65535)
        except socket.timeout:
            continue
        text = data.decode(errors="replace")
        if text.startswith("не знаю команду") == False:
            print(f"[{time.strftime('%H:%M:%S')}] Acer: {text}", file=log, flush=True)
if sys.argv[1] == "say":
    text = " ".join(sys.argv[2:])
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("10.0.0.1", 0))
    sock.sendto(("say " + text).encode(), AGENT)
    print(f"chat: отправлено {len(text.encode())} байт", flush=True)
