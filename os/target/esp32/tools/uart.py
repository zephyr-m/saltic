# uart — сброс ESP32 DevKit через RTS и чтение UART0 115200: всё, что плата
# напишет за секунды, — в stdout. Запуск (pyserial есть рядом с esptool):
#   nix-shell -p esptool --run "python3 os/target/esp32/tools/uart.py /dev/ttyUSB0 4"
import sys
import time

import serial

port = serial.Serial(sys.argv[1], 115200, timeout=0.1)
port.dtr = False
port.rts = True
time.sleep(0.1)
port.rts = False
end = time.time() + float(sys.argv[2])
data = b""
while time.time() < end:
    data += port.read(4096)
sys.stdout.write(data.decode("utf-8", "replace"))
