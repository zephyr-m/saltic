# os — то, что ещё не переехало

Своей ОС у Saltic пока нет: понимание у автора сырое (22.11.2026), договор
ОС ещё не описан. Папка — остаток прежней раскладки, она пустеет по шагам:

- `drivers/`, `target/android` (мост к C), `target/linux` (адаптер Wayland) —
  в реестр адаптеров `saltic-registry/registry/adapters/<платформа>/`;
- библиотеки `fonts`, `screen`, `text`, `network`, `icons`, `input` и стенд Acer
  (`target/uefi_x86_64`: platform, screen, storage, agent) — их берут пакеты
  реестра (uiengine, qca9377, intel_gpu…) по путям `os.…`: связь задом наперёд,
  развернуть её — шаг 4, вместе с драйверами;
- `uiengine/` (старый движок) — в архив, когда его последние пользователи
  (программы Acer) переедут на JTML из библиотеки; `ui/playground` — в архив.

Уже переехало: программы — `soft/`, сборщики целей — `soul/toolchains/`,
инструменты на ноуте — `workbench/acer`, платы — `docs/hardware/boards`.
