# os — то, что ещё не переехало

Своей ОС у Saltic пока нет: понимание у автора сырое (22.11.2026), договор
ОС ещё не описан. Папка — остаток прежней раскладки, в ней две вещи:

- **стенд Acer** — `target/uefi_x86_64` (agent, screen с панелями, storage:
  notes и disk) и `network` (remote, reply, shot, stream, netlog, mrpc). Это
  программа стенда, а не адаптер: реестр её не берёт, она сама берёт пакеты
  (firmware, gop, files, net, драйверы Acer) через tarantul;
- **старый uiengine** (`uiengine/`) — в архив, когда его последние пользователи
  (программы Acer) переедут на JTML из библиотеки.

Уже переехало (22.11.2026): программы — `soft/`; сборщики целей —
`soul/toolchains/`; инструменты на ноуте — `workbench/acer`; платы —
`docs/hardware/boards`; text — в язык (`soul/craft/text`); прошивка UEFI,
экран gop, файлы, сеть, холст graphics, fonts, icons, input, lettering, ink,
драйверы платы qemu_virt, мост к C на Android (clib) и окно Wayland — в
реестр `saltic-registry`, программы берут их через tarantul. Реестр в
репозиторий Saltic больше не смотрит.
