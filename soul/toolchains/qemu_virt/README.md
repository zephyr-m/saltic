# QEMU virt platform

Bare-metal реализация платформенных возможностей для RV32I на машине
`qemu-virt`.

Звук выводится напрямую через VirtIO Sound: драйвер Saltic поднимает
стерео PCM S16 на 48 кГц, а QEMU передаёт его в PipeWire.
