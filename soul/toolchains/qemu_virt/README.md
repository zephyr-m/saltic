# QEMU virt platform

Сборщик голого ELF для RV32I на машине `qemu-virt`: `main.saltic`, дымовая
проверка — `checks/smoke`. Платформа — `compiler.gorn.platform.qemu_virt`,
драйверы платы — пакет реестра `qemu_virt`, стол с программами —
`soft/system/qemu_desk`.

Звук — через VirtIO Sound: драйвер `qemu_virt.sound` поднимает
стерео PCM S16 на 48 кГц, а QEMU передаёт его в PipeWire.
