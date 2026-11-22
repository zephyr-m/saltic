"""Посылка для Wi-Fi QCA9377: данные платы, OTP и прошивка одним файлом.

Берёт прошивку ath10k из системы (NixOS кладёт linux-firmware в
/run/current-system/firmware, файлы сжаты zstd) и раскладывает так, как ждёт
драйвер qca9377: плата Lite-On 11ad:08a6 с 0, OTP с 8192, сегменты прошивки
с 32768, каждый с границы 4 байт. Печатает таблицу сегментов — она же
SEGMENTS в qca9377/boot.saltic.
    python3 tools/wifi_pack.py /tmp/wifi-pack.bin
"""
import struct
import subprocess
import sys
from pathlib import Path

SOURCE = Path("/run/current-system/firmware/ath10k/QCA9377/hw1.0")
BOARD_NAME = "bus=pci,vendor=168c,device=0042,subsystem-vendor=11ad,subsystem-device=08a6"
OTP_AT, FIRMWARE_AT = 8192, 32768


def unpack(name):
    print(f"wifi_pack: распаковываю {name}", flush=True)
    return subprocess.run(["zstd", "-dc", str(SOURCE / f"{name}.zst")], check=True, capture_output=True).stdout


def elements(data, start):
    at, found = start, {}
    while at + 8 <= len(data):
        kind, length = struct.unpack_from("<II", data, at)
        found.setdefault(kind, []).append(data[at + 8:at + 8 + length])
        at += 8 + (length + 3) // 4 * 4
    return found


if len(sys.argv) != 2:
    sys.exit(__doc__)
firmware = elements(unpack("firmware-6.bin"), 12)
board = None
for entry in elements(unpack("board-2.bin"), 20)[0]:
    parts = elements(entry, 0)
    if parts[0][0].decode() == BOARD_NAME:
        board = parts[1][0]
if board is None:
    sys.exit(f"wifi_pack: в board-2.bin нет платы {BOARD_NAME}")
pack = bytearray(board) + bytes(OTP_AT - len(board)) + firmware[4][0]
pack += bytes(FIRMWARE_AT - len(pack))
image, at, segments = firmware[3][0], 8, []
while at + 8 <= len(image):
    address, length = struct.unpack_from("<II", image, at)
    at += 8
    if length == 0xFFFFFFFD:
        print(f"wifi_pack: старт прошивки {address:#x}")
        continue
    if length == 0xFFFFFFFF:
        break
    pack += bytes(-len(pack) % 4)
    segments.append([address, len(pack), length])
    pack += image[at:at + length]
    at += length
Path(sys.argv[1]).write_bytes(pack)
print(f"wifi_pack: плата {len(board)} байт, OTP {len(firmware[4][0])} байт, прошивка {sum(s[2] for s in segments)} байт")
print(f"wifi_pack: SEGMENTS = {segments}")
print(f"wifi_pack: записал {sys.argv[1]}, {len(pack)} байт")
