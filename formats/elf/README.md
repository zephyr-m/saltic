# ELF

- **Расширение:** без расширения, `.elf`, `.so`.
- **Где запускается:** Linux, BSD, Android (Termux), голое железо (qemu-virt).
- **Состояние:** ✅ есть, но не здесь: ELF32 — `soul/seed/selfhost/compiler/backend/rv32i/machine/image.saltic`, ELF64 — `soul/seed/selfhost/compiler/backend/x86_64_native/image.saltic` и `rv64/machine/elf64.saltic`. Переедут сюда.
- **Заметка:** один формат на любую архитектуру: RV32I, x86-64, Thumb-2, ARM64 различаются только полем машины.
