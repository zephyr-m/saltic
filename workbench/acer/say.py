import socket
import sys

from acer_address import route

command = " ".join(sys.argv[1:]) or "help"
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.settimeout(5)
LOCAL, AGENT = route()
sock.bind((LOCAL, 0))
sock.sendto(command.encode(), (AGENT, 5555))
try:
    data, _ = sock.recvfrom(65535)
except socket.timeout:
    print(f"Saltic не ответил на «{command}» за 5 секунд", file=sys.stderr)
    sys.exit(1)
print(data.decode(errors="replace"))
