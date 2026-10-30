# План полного закрытия seed

Обозначения:

- `[+]` — новый файл;
- `[~]` — существующий файл;
- `[-]` — удалить по плану или уже удалено с явной отметкой.
- `ГОТОВО` — запланированная работа выполнена;
- `ЧАСТИЧНО` — работа начата, но пункт ещё не закрыт;
- `НЕ НАЧАТО` — запланированная работа отсутствует.

Состояние плана после проверки 25 августа 2026 года:

- пункт 1 — `ГОТОВО` в объёме старого плана;
- пункт 2 — `ГОТОВО` как контракт, но ещё не применено действующим compiler/runtime;
- пункт 3 — `ГОТОВО` как контракт, реального освобождения памяти ещё нет;
- пункт 4 — `ГОТОВО`, таблица стала единым decoder-профилем VM;
- пункт 5 — `ГОТОВО`, доказан воротами `stage-3-machine`;
- пункт 6 — `НЕ ЗАКРЫТ`;
- пункт 7 — `ЧАСТИЧНО`: независимая machine-mode VM готова, parity с
  `qemu-system-riscv32` остаётся частью будущей virt-композиции;
- пункт 8 — `ЧАСТИЧНО`: текущий GNU-based fixed point восстановлен, прямого
  ELF fixed point без GNU ещё нет.

Нумерация этого документа историческая: пункт 5 здесь соответствует шагу 1
в `2026-08-24-seed-implementation-order.md` и воротам `stage-3-machine`, а не
воротам `stage-5-memory`.

Статусы 1–4 описывают объём старого плана и не означают прохождение новых
ворот `stage-1-language` и `stage-2-abi`: новые ворота требуют более сильного
сквозного доказательства.

Прогноз: 4600–7580 затронутых строк, чистый рост — 1500–3000 строк.

```text
ЗАКРЫТИЕ SEED — 4600–7580 затронутых строк
чистый рост — 1500–3000 строк

├─ 1. Однозначная семантика — 500–850 — ГОТОВО В ОБЪЁМЕ СТАРОГО ПЛАНА
│  ├─ [+] soul/seed/checker/signatures.saltic       160–240 — ГОТОВО
│  ├─ [+] soul/seed/checker/rules.saltic            180–280 — ГОТОВО
│  ├─ [~] soul/seed/checker/types.saltic             70–130 — ГОТОВО
│  ├─ [~] soul/seed/checker/semantics.saltic         60–100 — ГОТОВО
│  ├─ [~] soul/seed/parser/syntax.saltic             20–60 — ГОТОВО
│  └─ [~] soul/seed/ast.saltic                       10–40 — ГОТОВО
│
├─ 2. Единый ABI значений и вызовов — 450–800 — ГОТОВО КАК КОНТРАКТ
│  ├─ [+] soul/seed/abi/value.saltic                120–190 — ГОТОВО
│  ├─ [+] soul/seed/abi/call.saltic                 130–220 — ГОТОВО
│  ├─ [+] soul/seed/abi/object.saltic               100–180 — ГОТОВО
│  ├─ [~] soul/seed/abi/tags.saltic                  30–70 — ГОТОВО
│  ├─ [~] soul/seed/abi/fixed.saltic                 40–80 — ГОТОВО
│  ├─ [~] soul/seed/abi/errors.saltic                20–50 — ГОТОВО
│  └─ [~] soul/seed/abi.saltic                       10–30 — ГОТОВО
│
├─ 3. Константы и конечная модель памяти — 350–700 — ГОТОВО КАК КОНТРАКТ
│  ├─ [+] soul/seed/memory/model.saltic             120–200 — ГОТОВО
│  ├─ [+] soul/seed/compiler/constants.saltic       140–240 — ГОТОВО
│  ├─ [+] soul/seed/runtime/memory.saltic           180–280 — ГОТОВО
│  ├─ [~] soul/seed/compiler/state.saltic            40–100 — ГОТОВО
│  └─ [~] soul/seed/compiler/codegen.saltic          50–160 — ГОТОВО
│
├─ 4. Точный профиль процессора — 100–180 — ГОТОВО
│  ├─ [+] soul/seed/machine/profile.saltic           40–70 — ГОТОВО
│  └─ [+] soul/seed/machine/instruction.saltic       60–110 — ГОТОВО
│       └─ единственная таблица: 40 базовых + 4 машинных команды
│
├─ 5. Собственное кодирование и образ — 900–1400 — ГОТОВО
│  ├─ [~] soul/seed/machine/instruction.saltic — ГОТОВО
│  │    └─ одна кэшированная таблица 40 базовых + 4 машинных команд
│  ├─ [~] soul/seed/machine/codec.saltic — ГОТОВО
│  │    └─ chunked Buffer, append и произвольные read/write без плоского роста
│  ├─ [~] soul/seed/machine/layout.saltic — ГОТОВО
│  │    └─ секции, адреса, labels и patches в конечных связанных структурах
│  ├─ [-] soul/seed/machine/program.saltic — УДАЛЕНО
│  │    └─ был дублем layout; отдельный владелец модели программы не возвращается
│  ├─ [~] soul/seed/machine/image.saltic — ГОТОВО
│  │    └─ структурный ELF и запись chunked-байтов без повторной flat group
│  ├─ [~] soul/seed/runtime/runtime.saltic — ГОТОВО ДЛЯ ПУНКТА 5
│  │    └─ seed.file.write_bytes принимает как плоские bytes, так и chunks
│  ├─ [~] soul/seed/compiler/backend/rv32i.saltic — ГОТОВО ДЛЯ ПУНКТА 5
│  └─ [+] soul/seed/tests/machine/ — ГОТОВО
│       ├─ golden bytes всех 44 команд
│       ├─ границы immediate и все семь patch kinds
│       ├─ структура host/virt ELF
│       ├─ scale payload 64 KiB и проверка chunk boundaries
│       └─ один собственный host ELF выполнен собственной VM и qemu-riscv32
│
├─ 6. Перевод компилятора, runtime и платформы — 1400–2200
│  ├─ [+] soul/seed/compiler/abi.saltic             220–330
│  ├─ [~] soul/seed/compiler/state.saltic           100–160
│  ├─ [~] soul/seed/compiler/codegen.saltic         150–240
│  ├─ [+] soul/seed/runtime/start.saltic             80–120
│  ├─ [+] soul/seed/runtime/value.saltic            100–150
│  ├─ [+] soul/seed/runtime/group.saltic            180–260
│  ├─ [+] soul/seed/runtime/string.saltic           260–380
│  ├─ [+] soul/seed/runtime/platform.saltic          80–120
│  ├─ [~] soul/seed/runtime/runtime.saltic           30–60
│  │    └─ останется сборщиком модулей runtime
│  ├─ [+] soul/seed/platform/contract.saltic         70–110
│  ├─ [+] os/bootstrap/platform.saltic               80–130
│  └─ [~] os/target/qemu_virt/platform.saltic        80–130
│
├─ 7. VM совпадает с настоящей машиной — 450–750 — ЧАСТИЧНО
│  ├─ [+] soul/seed/vm/word.saltic                  140–220 — НЕ ВЫНЕСЕНО
│  ├─ [+] soul/seed/vm/memory.saltic                120–190 — НЕ ВЫНЕСЕНО
│  ├─ [+] soul/seed/vm/system.saltic                100–170 — ГОТОВО
│  │    └─ ловушки, системные регистры, ожидание, возврат
│  ├─ [~] soul/seed/vm/state.saltic                  30–60 — ГОТОВО ДЛЯ MACHINE MODE
│  ├─ [~] soul/seed/vm/cpu.saltic                    30–70 — ГОТОВО ДЛЯ MACHINE MODE
│  ├─ [~] soul/seed/vm/loader.saltic                 20–50 — ГОТОВО ДЛЯ 0x80000000
│  ├─ [~] soul/seed/vm/syscalls.saltic               10–30 — ГОТОВО ДЛЯ PROCESS MODE
│  └─ [+] soul/seed/tests/vm-machine.saltic — ГОТОВО
│
└─ 8. Доказательство замкнутости — 450–700 — ЧАСТИЧНО
   ├─ [+] soul/seed/tests/closure.saltic             250–380
   │    ├─ все 40 команд
   │    ├─ ABI значений и вызовов
   │    ├─ константы без роста кучи
   │    ├─ один образ в VM и QEMU
   │    └─ длительная работа без утечки
   ├─ [+] soul/seed/tests/expected/closure.txt        40–80
   ├─ [~] tests/run.sh                                80–120 — ЧАСТИЧНО
   ├─ [~] os/bootstrap/build.sh                       40–60 — ЧАСТИЧНО
   ├─ [~] os/bootstrap/refresh.sh                     40–60 — ЧАСТИЧНО
   │
   └─ финальное удаление
      ├─ [-] soul/seed/answer.saltic
      ├─ [-] soul/seed/error.saltic
      ├─ [-] soul/seed/compiler/backend/xtensa-lx6.saltic
      ├─ [-] os/bootstrap/linux-memory.S
      ├─ [-] os/target/qemu_virt/platform.S
      └─ [-] tests/fixtures/vm-canonical.S
```

Первоначальные оценки числа недостающих файлов после фактической реализации
пункта 5 больше не используются. Актуальный остаток определяется пунктами 6–8
и полным аудитом от 24 августа 2026 года.

## Фактическое доказательство пункта 5

Команда `just stage-3-machine` завершена успешно 24 августа 2026 года:

- machine-набор: 132 проверки пройдено, 0 провалено;
- созданный image-builder ELF: 4 проверки собственной VM пройдено, 0 провалено;
- тот же записанный `generated.elf` завершился с кодом 0 в `qemu-riscv32`;
- Unix execute-bit выставляется воротами после записи ELF; это метаданные файла,
  а не часть байтов ELF и не второй image-writer.

Фактический объём пункта по текущему diff: около 1134 затронутых строк —
600 добавлено и 534 удалено, чистый рост около 66 строк. Сопутствующие изменения
bootstrap в этот подсчёт не входят.

Пункт 5 закрыт полностью. Его критерии не переносятся в пункты 6–8.

## Фактическое доказательство независимой части пункта 7

Проверки завершены успешно 25 августа 2026 года:

- `just test vm-machine`: 10 проверок, 0 провалов;
- общий decoder распознаёт команды по единственной таблице 44 видов;
- virt ELF загружен и исполнен собственной VM с адреса `0x80000000`;
- подтверждены `csrrw`, `csrrs`, `mret`, `wfi`, machine `ecall` и CSR trap-flow;
- подтверждены UART и QEMU test MMIO;
- `just test vm`: прежний process-mode прошёл нативную проверку.

Этим завершена независимая от ABI машинная часть VM. Весь старый пункт 7
остаётся частичным до одного virt ELF с одинаковым результатом в собственной VM
и `qemu-system-riscv32`; отдельное вынесение `vm/word.saltic` и
`vm/memory.saltic` также пока не выполнено.

## Сопутствующее восстановление bootstrap

Новый chunk-aware runtime потребовал обновить зафиксированный compiler. Для этого
выполнена аварийная, но воспроизводимая перековка существующего bootstrap:

- `os/bootstrap/link.sh` стал единым местом GNU assembly → ELF для текущего
  переходного bootstrap;
- `os/bootstrap/build.sh` использует этот общий linker-path;
- стандартная heap сборки и тестового helper поднята с 16 MiB до 512 MiB;
- `os/bootstrap/refresh.sh` умеет входить в проектный Nix shell, собирать rescue
  compiler и все поколения с heap `4026531840`, проводить stage 1 → 2 → 3 и
  проверять fixed point;
- в корневой `justfile` добавлен `bootstrap-rescue`;
- `os/bootstrap/compiler.elf` обновлён после успешного fixed point, SHA-256:
  `7135ef47b583bc3e56773dc7797f2b70c710cb43a4d7e6d467dfe48047fe2a27`.

Это восстановило текущий GNU-based bootstrap, но не закрывает пункт 8: прямой
ELF fixed point без GNU assembler/linker остаётся отдельной будущей работой.
