import select
import socket
import struct
import sys
import time

interface = sys.argv[1] if len(sys.argv) > 1 else "eno1"
target_mac = bytes.fromhex("a81e84ea1037")
my_ip = bytes([10, 0, 0, 1])
target_ip = bytes([10, 0, 0, 2])
my_port, target_port = 5556, 5555

sock = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(0x0003))
sock.bind((interface, 0))
my_mac = sock.getsockname()[4]


def checksum(header):
    total = sum(struct.unpack(">10H", header))
    while total > 0xFFFF:
        total = (total & 0xFFFF) + (total >> 16)
    return 0xFFFF - total


def frame(text):
    payload = text.encode()
    udp = struct.pack(">4H", my_port, target_port, 8 + len(payload), 0) + payload
    ip = struct.pack(">BBHHHBBH4s4s", 0x45, 0, 20 + len(udp), 1, 0, 64, 17, 0, my_ip, target_ip)
    ip = ip[:10] + struct.pack(">H", checksum(ip)) + ip[12:]
    return target_mac + my_mac + b"\x08\x00" + ip + udp


print(f"говорю с Saltic через {interface} ({my_mac.hex(':')}), шлю ping раз в секунду. Ctrl+C — выход", flush=True)
number = 0
next_ping = time.time()
while True:
    now = time.time()
    if now >= next_ping:
        number += 1
        sock.send(frame(f"ping {number}"))
        print(f"[{time.strftime('%H:%M:%S')}] -> ping {number}", flush=True)
        next_ping = now + 1
    ready, _, _ = select.select([sock], [], [], max(0, next_ping - time.time()))
    if not ready:
        continue
    data = sock.recv(2048)
    if data[6:12] != target_mac:
        continue
    kind = struct.unpack(">H", data[12:14])[0]
    line = f"[{time.strftime('%H:%M:%S')}] <- {len(data)} байт от Saltic, тип {kind:#06x}"
    if kind == 0x0800 and data[23] == 17:
        length = struct.unpack(">H", data[38:40])[0]
        line += f": {data[42:34 + length].decode(errors='replace')!r}"
    print(line, flush=True)
