# log_receiver — журнал Acer по кабелю к нам в файл (network/stream.saltic):
# слушает UDP 5557, каждую строку дописывает в .cache/acer/net.log с нашим
# временем до миллисекунд и печатает на экран. Раз в 10 секунд шлёт на Acer
# пустой пакет с того же порта — файрвол хоста тогда считает строки Acer
# ответом и пропускает их без правки настроек. Ctrl+C — выход.
#
#   python3 workbench/acer/log_receiver.py [файл]

import os
import socket
import sys
import time

PORT = 5557
ACER = ("10.0.0.2", PORT)
KEEP = 10

path = sys.argv[1] if len(sys.argv) > 1 else ".cache/acer/net.log"
os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind(("0.0.0.0", PORT))
sock.settimeout(1)
print(f"журнал Acer: слушаю UDP {PORT}, пишу в {path}. Ctrl+C — выход", flush=True)

lines = 0
poked = 0
with open(path, "a", encoding="utf-8") as log:
    log.write(f"--- приёмник запущен {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
    log.flush()
    while True:
        if time.time() - poked >= KEEP:
            try:
                sock.sendto(b"", ACER)
            except OSError as err:
                print(f"не достучалась до Acer: {err}", flush=True)
            poked = time.time()
        try:
            data, sender = sock.recvfrom(2048)
        except socket.timeout:
            continue
        if sender[0] != ACER[0] or not data:
            continue
        stamp = time.strftime("%H:%M:%S") + f".{int(time.time() * 1000) % 1000:03d}"
        line = f"{stamp} {data.decode(errors='replace')}"
        log.write(line + "\n")
        log.flush()
        lines += 1
        print(line, flush=True)
