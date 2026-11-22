import socket
import struct
import sys
import time

interface = sys.argv[1] if len(sys.argv) > 1 else "eno1"
sock = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(0x0003))
sock.bind((interface, 0))
mine = sock.getsockname()[4].hex(":")
print(f"слушаю {interface} ({mine}), жду кадры от Saltic. Ctrl+C — выход", flush=True)

while True:
    frame = sock.recv(2048)
    src = frame[6:12].hex(":")
    kind = struct.unpack(">H", frame[12:14])[0]
    stamp = time.strftime("%H:%M:%S")
    if src == mine:
        continue
    line = f"[{stamp}] {len(frame)} байт от {src}, тип {kind:#06x}"
    if kind == 0x0800 and frame[23] == 17:
        sport, dport, length = struct.unpack(">3H", frame[34:40])
        src_ip = ".".join(map(str, frame[26:30]))
        dst_ip = ".".join(map(str, frame[30:34]))
        payload = frame[42:34 + length].decode(errors="replace")
        line += f" | UDP {src_ip}:{sport} -> {dst_ip}:{dport}: {payload!r}"
    print(line, flush=True)
