# ELF

- **Расширение:** без расширения, `.elf`, `.so`.
- **Где запускается:** Linux, BSD, Android (Termux), голое железо (qemu-virt).
- **Состояние:** ✅ есть, но не здесь: ELF32 — `soul/seed/selfhost/machine/image.saltic`, ELF64 — `soul/seed/selfhost/compiler/backend/x86_64_translation/image.saltic`. Переедут сюда.
- **Заметка:** один формат на любую архитектуру: RV32I, x86-64, Thumb-2, ARM64 различаются только полем машины.
