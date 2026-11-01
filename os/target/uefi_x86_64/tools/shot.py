import socket
import struct
import sys
import time
import zlib

path = sys.argv[1] if len(sys.argv) > 1 else "shot.png"
AGENT = ("10.0.0.2", 5555)
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind(("10.0.0.1", 0))
sock.settimeout(30)
started = time.time()
sock.sendto(b"shot", AGENT)
reply = sock.recvfrom(65535)[0].decode(errors="replace")
words = reply.split()
if len(words) != 5 or words[0] != "снимок":
    print(f"shot: агент ответил не снимком: {reply}", file=sys.stderr)
    sys.exit(1)
width, height, total, chunks = map(int, words[1:])
print(f"shot: экран {width} × {height}, {total} байт, {chunks} кусков", flush=True)
data = bytearray(total)
sock.settimeout(1)
retries = 0
for index in range(chunks):
    while True:
        sock.sendto(f"shot-part {index}".encode(), AGENT)
        try:
            packet = sock.recvfrom(65535)[0]
        except socket.timeout:
            retries += 1
            if retries > 50:
                print(f"shot: агент молчит на куске {index}", file=sys.stderr)
                sys.exit(1)
            continue
        number = struct.unpack(">HH", packet[:4])
        if number[0] * 65536 + number[1] != index:
            continue
        size = min(1024, total - index * 1024)
        data[index * 1024:index * 1024 + size] = packet[4:4 + size]
        break
    if index % 100 == 0:
        print(f"shot: {index} из {chunks}", flush=True)
rows = b"".join(b"\0" + bytes(data[y * width * 3:(y + 1) * width * 3]) for y in range(height))


def chunk(kind, body):
    return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)


with open(path, "wb") as out:
    out.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))
print(f"shot: {path} — {time.time() - started:.1f} с, повторов {retries}", flush=True)
