# План полного закрытия seed

Обозначения:

- `[+]` — новый файл;
- `[~]` — существующий файл;
- `[-]` — удалить только в финале.
- `ГОТОВО` — запланированная работа выполнена;
- `ЧАСТИЧНО` — работа начата, но пункт ещё не закрыт;
- `НЕ НАЧАТО` — запланированная работа отсутствует.

Состояние пунктов 1–4 на 23 августа 2026 года:

- пункт 1 — `ГОТОВО`;
- пункт 2 — `ГОТОВО`;
- пункт 3 — `ГОТОВО`;
- пункт 4 — `ГОТОВО`;
- пункты 5–8 здесь пока не оцениваются.

Прогноз: 4600–7580 затронутых строк, чистый рост — 1500–3000 строк.

```text
ЗАКРЫТИЕ SEED — 4600–7580 затронутых строк
чистый рост — 1500–3000 строк

├─ 1. Однозначная семантика — 500–850 — ГОТОВО
│  ├─ [+] soul/seed/checker/signatures.saltic       160–240 — ГОТОВО
│  ├─ [+] soul/seed/checker/rules.saltic            180–280 — ГОТОВО
│  ├─ [~] soul/seed/checker/types.saltic             70–130 — ГОТОВО
│  ├─ [~] soul/seed/checker/semantics.saltic         60–100 — ГОТОВО
│  ├─ [~] soul/seed/parser/syntax.saltic             20–60 — ГОТОВО
│  └─ [~] soul/seed/ast.saltic                       10–40 — ГОТОВО
│
├─ 2. Единый ABI значений и вызовов — 450–800 — ГОТОВО
│  ├─ [+] soul/seed/abi/value.saltic                120–190 — ГОТОВО
│  ├─ [+] soul/seed/abi/call.saltic                 130–220 — ГОТОВО
│  ├─ [+] soul/seed/abi/object.saltic               100–180 — ГОТОВО
│  ├─ [~] soul/seed/abi/tags.saltic                  30–70 — ГОТОВО
│  ├─ [~] soul/seed/abi/fixed.saltic                 40–80 — ГОТОВО
│  ├─ [~] soul/seed/abi/errors.saltic                20–50 — ГОТОВО
│  └─ [~] soul/seed/abi.saltic                       10–30 — ГОТОВО
│
├─ 3. Константы и конечная модель памяти — 350–700 — ГОТОВО
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
├─ 5. Собственное кодирование и образ — 900–1400
│  ├─ [+] soul/seed/machine/codec.saltic            250–380
│  ├─ [+] soul/seed/machine/program.saltic          250–380
│  │    └─ метки, секции, адреса, исправления ссылок
│  ├─ [+] soul/seed/machine/image.saltic            220–340
│  │    └─ готовый исполняемый файл
│  └─ [~] soul/seed/compiler/backend/rv32i.saltic   180–300
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
├─ 7. VM совпадает с настоящей машиной — 450–750
│  ├─ [+] soul/seed/vm/word.saltic                  140–220
│  ├─ [+] soul/seed/vm/memory.saltic                120–190
│  ├─ [+] soul/seed/vm/system.saltic                100–170
│  │    └─ ловушки, системные регистры, ожидание, возврат
│  ├─ [~] soul/seed/vm/state.saltic                  30–60
│  ├─ [~] soul/seed/vm/cpu.saltic                    30–70
│  ├─ [~] soul/seed/vm/loader.saltic                 20–50
│  └─ [~] soul/seed/vm/syscalls.saltic               10–30
│
└─ 8. Доказательство замкнутости — 450–700
   ├─ [+] soul/seed/tests/closure.saltic             250–380
   │    ├─ все 40 команд
   │    ├─ ABI значений и вызовов
   │    ├─ константы без роста кучи
   │    ├─ один образ в VM и QEMU
   │    └─ длительная работа без утечки
   ├─ [+] soul/seed/tests/expected/closure.txt        40–80
   ├─ [~] tests/run.sh                                80–120
   ├─ [~] os/bootstrap/build.sh                       40–60
   ├─ [~] os/bootstrap/refresh.sh                     40–60
   │
   └─ финальное удаление
      ├─ [-] soul/seed/answer.saltic
      ├─ [-] soul/seed/error.saltic
      ├─ [-] soul/seed/compiler/backend/xtensa-lx6.saltic
      ├─ [-] os/bootstrap/linux-memory.S
      ├─ [-] os/target/qemu_virt/platform.S
      └─ [-] tests/fixtures/vm-canonical.S
```

Недостающих производственных файлов: 24.

Недостающих проверочных файлов: 2.
