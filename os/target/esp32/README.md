# ESP32

Платформа и сборщик есть: `platform.saltic`, `toolchain.saltic`, `smoke.saltic`.
Сборка: `toolchain <исходник> <образ.bin> <куча байт>` — куча не больше 64 КБ.
Прошивка: `esptool --chip esp32 --port /dev/ttyUSB0 --no-stub write-flash 0x1000 образ.bin`.
Память тела: свободной DRAM около 180 КБ; арена 16 КБ и куча 64 КБ по
умолчанию — в `platform.saltic`.
Экран SSD1306 128×64 (13.11.2026): `i2c.saltic` — I2C ногодрыгом, SDA — D23,
SCL — D22, VCC — 3V3; `ssd1306.saltic` — текст Spleen 5×8 с кириллицей;
программа `oled.saltic`, сканер шины `i2c_scan.saltic`. GPIO и IO_MUX — только
по адресам AHB (`0x6000_4000`): по `0x3FF4_4000` блок GPIO молчит.
Проверка на плате, без неё — сверка кодировщика: `just esp32`.
Кварц этой платы 40 МГц, UART 115200. Запись по 0x1000 затирает второй загрузчик. Записана 03.11.2026.

- **Платы:** ESP32-CAM, ESP32-WROVER (4–8 МБ PSRAM).
- **Бэкенд:** Xtensa LX6 — `soul/seed/selfhost/compiler/backend/`.
- **Зачем:** Wi-Fi и камера за $5–10; ESP32 автора может оказаться WROVER.
- **Когда:** эпоха 3 — ядро ОС и параллельно проверка на железе.
- **Документация:** ESP32 Technical Reference Manual (Espressif).
- **Подробно:** `.archive/docs/PLAN-1.md, раздел «Железо и бэкенды»`; одна ОС на всё железо — `docs/os/OS-core.md`.
