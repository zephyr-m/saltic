# ESP32 — заглушка

Платформа и сборщик есть: `platform.saltic`, `toolchain.saltic`, `smoke.saltic`.
Прошивка: `esptool --chip esp32 --port /dev/ttyUSB0 --no-stub write-flash 0x1000 образ.bin`.
Кварц этой платы 40 МГц, UART 115200. Запись по 0x1000 затирает второй загрузчик. Записана 03.11.2026.

- **Платы:** ESP32-CAM, ESP32-WROVER (4–8 МБ PSRAM).
- **Бэкенд:** Xtensa LX6 — `soul/seed/selfhost/compiler/backend/`.
- **Зачем:** Wi-Fi и камера за $5–10; ESP32 автора может оказаться WROVER.
- **Когда:** эпоха 3 — ядро ОС и параллельно проверка на железе.
- **Документация:** ESP32 Technical Reference Manual (Espressif).
- **Подробно:** `.archive/docs/PLAN-1.md, раздел «Железо и бэкенды»`; одна ОС на всё железо — `docs/os/OS-core.md`.
