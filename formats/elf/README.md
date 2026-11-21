# ELF

- **Расширение:** без расширения, `.elf`, `.so`.
- **Где запускается:** Linux, BSD, Android (Termux), голое железо (qemu-virt).
- **Состояние:** ✅ есть, но не здесь: ELF32 — `soul/seed/compiler/gorn/backend/image.saltic`, ELF64 — `soul/seed/compiler/gorn/backend/x86/x86_64/image.saltic` и `soul/seed/compiler/gorn/linker/elf64.saltic` (RV64 и ARM64). Переедут сюда.
- **Заметка:** один формат на любую архитектуру: RV32I, x86-64, Thumb-2, ARM64 различаются только полем машины.
