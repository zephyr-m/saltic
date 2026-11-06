import socket
import struct
import sys
import time

from acer_address import route

CHUNK = 1024
COMMAND_PORT, DATA_PORT = 5555, 5556

if len(sys.argv) < 2:
    print("использование: python3 tools/upload.py <файл.efi> [--run]", file=sys.stderr)
    sys.exit(2)
path = sys.argv[1]
run = "--run" in sys.argv[2:]
data = open(path, "rb").read()

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
LOCAL, AGENT = route()
sock.bind((LOCAL, 0))


def ask(text, timeout=5):
    sock.settimeout(timeout)
    sock.sendto(text.encode(), (AGENT, COMMAND_PORT))
    reply, _ = sock.recvfrom(65535)
    return reply.decode(errors="replace")


print(f"upload: {path}, {len(data)} байт", flush=True)
answer = ask(f"upload {len(data)}")
print(f"upload: агент говорит: {answer}", flush=True)
if answer.startswith("жду") == False:
    print("upload: агент не принял заливку, останавливаюсь", file=sys.stderr)
    sys.exit(1)

started = time.time()
offset = 0
retries = 0
next_report = 0
sock.settimeout(1)
while offset < len(data):
    piece = data[offset:offset + CHUNK]
    packet = struct.pack(">HH", offset >> 16, offset & 0xFFFF) + piece
    sock.sendto(packet, (AGENT, DATA_PORT))
    try:
        reply, _ = sock.recvfrom(65535)
    except socket.timeout:
        retries += 1
        if retries > 20:
            print(f"upload: агент молчит на смещении {offset}, сдаюсь", file=sys.stderr)
            sys.exit(1)
        continue
    text = reply.decode(errors="replace")
    if not text.startswith("ok "):
        continue
    offset = int(text[3:])
    if offset * 10 // len(data) >= next_report:
        print(f"upload: {offset} из {len(data)} байт ({offset * 100 // len(data)}%)", flush=True)
        next_report = offset * 10 // len(data) + 1

seconds = time.time() - started
print(f"upload: передано за {seconds:.1f} с, повторов {retries}", flush=True)
state = ask("check")
local_sum = sum(data) % 65536
print(f"upload: агент: {state}; сумма здесь {local_sum}", flush=True)
if state.split()[-1] != str(local_sum):
    print("upload: СУММЫ НЕ СОВПАЛИ", file=sys.stderr)
    sys.exit(1)
if run:
    print("upload: запускаю…", flush=True)
    print(f"upload: агент: {ask('run', timeout=120)}", flush=True)
