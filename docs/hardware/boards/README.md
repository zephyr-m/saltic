# Платы

Железо, на котором живёт или будет жить Saltic. Сборщик цели — в
`soul/toolchains/<цель>/`, программы — в `soft/<категория>/<программа>/`
(отличия платформ — в подпапке платформы), драйверы — `os/drivers`, потом
реестр адаптеров (`saltic-registry/registry/adapters/<платформа>/`).

Файл `<плата>.md` без сборщика — заглушка: плата записана в план, но ещё не
начата.

| Плата | Сборщик | Бэкенд | Состояние |
|---|---|---|---|
| QEMU virt | `soul/toolchains/qemu_virt` | RV32I | ✅ есть |
| Acer и любой ПК с UEFI | `soul/toolchains/saltic` (цель x86_64-uefi); стенд — `os/target/uefi_x86_64` | x86-64 | ✅ есть |
| Android (POCO X6 Pro) | `soul/toolchains/android` | ARM64 | ✅ есть |
| ESP32 DevKit | `soul/toolchains/esp32` | Xtensa LX6 | ✅ есть |
| Браузер и Node (WASI) | `soul/toolchains/wasm` | wasm32 | ✅ есть |
| RP2350 | — | RV32I, потом Thumb-2 | ⬜ [rp2350.md](rp2350.md) |
| STM32H7 | — | Thumb-2 (Cortex-M7) | ⬜ [stm32h7.md](stm32h7.md) |
| Teensy 4.1 | — | Thumb-2 (Cortex-M7) | ⬜ [teensy41.md](teensy41.md) |
| ESP32-S3 | — | Xtensa LX7 | ⬜ [esp32s3.md](esp32s3.md) |
| Raspberry Pi | — | ARM64 | ⬜ [raspberry_pi.md](raspberry_pi.md) |
| Orange Pi | — | ARM64 | ⬜ [orange_pi.md](orange_pi.md) |
