# Прогресс

Обновлено: 2026-09-23.

## Как вести этот файл

- Не удалять старые записи о группах и пропусках.
- Новую работу добавлять отдельным пунктом.
- Завершённый `TODO` отмечать на месте как `[x]`.
- Счётчики обновлять, не пересобирать остальные разделы.

## Сейчас

- Runtime переводится с текстового GNU assembly на `machine.Program`.
- Подтверждено: `just test machine` — 5548 пройдено, 0 провалено.
- Реализовано и подтверждено тестами 77 из 77 исполняемых точек runtime.

## Готовые группы

- Обычная арифметика и сравнения: `add`, `sub`, `mul`, `div`, `equal`, `less`, `greater`.
- Ошибка деления на ноль.
- Доступ к `Box`: чтение, запись и ошибка отсутствующего поля.
- Чтение `Group`: количество, элемент и ошибка границ.
- Чтение `String`: длина, байт и ошибка границ.
- Сравнение начала и конца `String`.
- Поиск подстроки в `String`.
- Подсчёт строк: `rt_line_count`.
- Платформа и CPU: `write`, `exit`, `wait`, `fence`.
- Запись файла и ошибка файла.
- `rt_newline` и `rt_missing_args`.
- Ошибки переполнения fixed.
- Сравнения fixed.

## Отложено: память

Эти пункты накапливаются здесь до возвращения к группе памяти.

### Сама группа памяти

- [x] `rt_alloc`
- [x] `rt_fixed_mem_load8`
- [x] `rt_fixed_mem_load16`
- [x] `rt_fixed_mem_load32`
- [x] `rt_fixed_mem_load`
- [x] `rt_fixed_mem_store8`
- [x] `rt_fixed_mem_store16`
- [x] `rt_fixed_mem_store32`
- [x] `rt_fixed_mem_store`
- [x] `rt_mem_load8`
- [x] `rt_mem_load16`
- [x] `rt_mem_load32`
- [x] `rt_mem_store8`
- [x] `rt_mem_store16`
- [x] `rt_mem_store32`
- [x] `rt_mem_store_address32`
- [x] `rt_out_of_memory`

### Прямо вызывают `rt_alloc`

- [x] `rt_fixed_new`
- [x] `rt_fixed_show`
- [x] `rt_group_add`
- [x] `rt_cstring`
- [x] `rt_string_add`
- [x] `rt_string_at`
- [x] `rt_string_slice`
- [x] `rt_string_case`
- [x] `rt_number_text`
- [x] `rt_file_read`
- [x] `rt_file_write_byte_group`

### Зависят от отложенных функций

- [x] `rt_fixed_add`
- [x] `rt_fixed_sub`
- [x] `rt_fixed_mul`
- [x] `rt_fixed_div`
- [x] `rt_fixed_and`
- [x] `rt_fixed_or`
- [x] `rt_fixed_xor`
- [x] `rt_fixed_not`
- [x] `rt_fixed_shift_left`
- [x] `rt_fixed_shift_right`
- [x] `rt_fixed_convert`
- [x] `rt_string_lower`
- [x] `rt_string_upper`
- [x] `rt_show`
- [x] `rt_file_write_bytes`

## TODO

- [x] `rt_line_count`: 1116/0.
- [x] Продолжить функциями без выделения памяти.
- [x] `rt_platform_write`, `rt_platform_exit`, `rt_cpu_wait`, `rt_cpu_fence`: 1170/0.
- [x] `rt_file_write`, `rt_file_error`: 1296/0.
- [x] `rt_newline`, `rt_missing_args`: 1380/0.
- [x] `rt_fixed_overflow_restore`, `rt_fixed_overflow`: 1410/0.
- [x] `rt_fixed_equal`, `rt_fixed_less`, `rt_fixed_greater`: 1640/0.
- [x] Вернуться к группе памяти.
- [x] `rt_alloc`, `rt_out_of_memory`: 1692/0.
- [x] `rt_fixed_new`: 1870/0.
- [x] `rt_fixed_mem_load8/16/32`, `rt_fixed_mem_load`: 1970/0.
- [x] `rt_fixed_mem_store8/16/32`, `rt_fixed_mem_store`: 2078/0.
- [x] `rt_mem_load8/16/32`: 2254/0.
- [x] `rt_mem_store8/16/32`: 2442/0.
- [x] `rt_mem_store_address32`: 2538/0.
- [x] `rt_fixed_show`: 2818/0.
- [x] `rt_group_add`: 2956/0.
- [x] `rt_cstring`: 3086/0.
- [x] `rt_string_add`: 3276/0.
- [x] `rt_string_at`: 3368/0.
- [x] `rt_string_slice`: 3516/0.
- [x] `rt_string_lower/upper/case`: 3706/0.
- [x] `rt_number_text`: 3950/0.
- [x] `rt_file_read`: 4102/0.
- [x] `rt_file_write_byte_group`: 4274/0.
- [x] `rt_fixed_add/sub`: 4408/0.
- [x] `rt_fixed_mul`: 4660/0.
- [x] `rt_fixed_div`: 4826/0.
- [x] `rt_fixed_and/or/xor/not`: 4942/0.
- [x] `rt_fixed_shift_left/right`: 5006/0.
- [x] `rt_fixed_convert`: 5054/0.
- [x] `rt_show`: 5302/0.
- [x] `rt_file_write_bytes`: 5548/0.
- [x] Цельный `machine.Program` runtime: 77/77 эмиттеров, 5 RODATA-меток, все patches разрешены — 5559/0.
- [x] Машинный `_start`: аргументы, heap, вызов программы и exit — 5568/0.
- [x] Машинный каркас функций: метки, frame, аргументы и общий return — 5577/0.
- [x] Машинные вызовы: 17/17 active call-sites и переходы `out` — тесты пройдены.
- [x] Машинные литералы, local load/store и аргументы `a0…a7`.
- [x] Обычная арифметика, сравнения, отрицательные immediate и runtime calls; wide fixed ожидает архитектурного решения.
- [x] Wide fixed: `codec` decimal text → 32-bit `Word`, `layout` → `LUI/ADDI`; арифметический блок закрыт.
- [x] Машинный control flow: `if`, `switch`, `drum`, `rescue`, `out`, constant-state labels/patches.
- [x] Дальний `_start` → `rt_missing_args`: локальная ветка и переход без ограничения `JAL` в ±1 МиБ.
- [x] Старый bootstrap-компилятор: `link.sh` нормализует его прежний короткий переход до обновления `compiler.elf`.
- [x] Машинные значения: String RODATA, Group/Box и чтение/запись полей.
- [x] Машинный codegen: opcode-проверки и VM-поведение String/arithmetic/if/Group/Box.
- [x] Обычная AST-программа собирается единым compiler-проходом в `machine.Program` и исполняется Saltic VM.
- [x] `runtime/memory.saltic`: удалён лишний `+` перед `use seed`, мешавший разбору модуля.
- [x] Тест обычной программы перенесён из области с локальным `compiler`, устранён конфликт имени модуля.
- [x] Один ELF обычной AST-программы проверяется на успешный exit в Saltic VM и `qemu-riscv32`.
- [x] VM и QEMU получают один готовый ELF-буфер; запись переведена на проверенный `image.write_buffer`.
- [x] Созданному host ELF выставляется execute-bit перед запуском в `qemu-riscv32`.
- [x] Машинный codegen подтверждён в Saltic VM и QEMU: 5749/0.
- [x] VM/QEMU-проверка вынесена из `machine.saltic` в существующий `machine/qemu.saltic`; ABI остаётся в `tests/abi.saltic`.
- [x] Сверен ABI: базовый вызов совпадает; объекты, error-return и fixed ещё используют старую runtime-схему.
- [x] Литералы находятся в RODATA, lazy storage констант перенесён в DATA `machine.Program`.
- [x] Writable storage и выровненный heap BSS с границами перенесены в `machine.Program`.
- [x] VM/QEMU-проверка использует heap компилятора без повторного определения тестовых меток.
- [x] Тестовая Saltic VM вмещает канонический heap 16 МиБ и загрузочные области ELF.
- [x] Getter констант читает и пишет DATA через существующие relative-address patches.
- [x] Подтверждён будущий контракт `rt_alloc`: `a0` содержит payload bytes; allocator добавляет 12-байтный header и выравнивание, записывает `payload_bytes` и нулевые flags; caller записывает `kind`.
- [x] БЛОКИРОВКА object ABI снята: fixed хранится как raw 32-bit word, boxed-представление удалено.
- [x] Механизм fixed kind выбран: source kind передаётся в `a6`, conversion target kind — в `a7`.
- [x] Точка продолжения выполнена: `rt_alloc`, String/Group/Box headers и fixed переведены на утверждённый ABI.
- [x] Решение fixed ABI: raw-значение не несёт kind; компилятор вызывает отдельную runtime-точку для каждого `u8/u16/u32/i32/bits32/address/usize`.
- [x] Блокировка object ABI снята; скрытый register-аргумент не используется, boxed fixed подлежит удалению.
- [x] Решение fixed ABI пересмотрено: единые `rt_fixed_*`, source kind в `a6`, conversion target kind в `a7`; отдельные точки по kind не создаются.
- [x] Компилятор передаёт fixed kind через канонические `a6/a7`; boxed runtime временно сохраняет совместимость до следующей группы.
- [x] Fixed runtime переведён с tagged `BOX` на raw word: операции читают kind из `a6/a7`, typed memory и конструкторы heap не используют.
- [x] String/Group/Box и `rt_alloc` переведены на единый 12-байтный header; static strings отмечены flag STATIC.
- [x] После итогов тестов повторно печатается короткий список всех `[FAIL]` с actual и expected.
- [x] Исправлен эталон `rt_missing_field`: error value 15 кодируется как `addi a0, zero, 15`.
- [x] Object ABI подтверждён полным прогоном: 5462 пройдено, 0 провалено.
- [x] `rt_alloc` проверяет сломанные границы, 32-битное переполнение и остаток квоты до сдвига cursor.
- [x] `compile_machine_with_heap` проводит размер heap в `machine.Program`, BSS и метки границ.
- [x] Heap `sed`: после bootstrap fixed point legacy-подмена удалена; сборка принимает только `.space SALTIC_HEAP_BYTES` и передаёт размер через `as --defsym`.
- [x] Memory ABI/data-layout/quota подтверждены полным прогоном: 5481 пройдено, 0 провалено.
- [x] Bootstrap refresh: исправлено затирание знака и буфера цифр в `rt_number_text` при вызове `rt_alloc`; добавлена VM-проверка строки `-42`.
- [x] Новый runtime подтверждён: 5503 пройдено, 0 провалено; bootstrap достиг fixed point и обновил `os/bootstrap/compiler.elf`.
- [x] Остаток контрольной точки 3: runtime переведён на raw error id в `a1`; успешные возвраты обнуляют `a1`.
- [x] `rescue` превращает raw id обратно в tagged `Error`; VM-проверки ABI подтверждены — 5780/0.
- [x] `_start` сохраняет `argv` в `s3`; подтверждено 5785/0 и bootstrap fixed point, compiler hash `d326dc05485ca5514447c64408d4615b7ac46f0dc1fe2746f30aa2821351859c`.
- [x] Блок 4, host: машинные entry/write/exit и замена `linux-memory.S` собственным low-memory PT_LOAD; добавлены 5 точных ELF-проверок.
- [x] Блок 4, virt-контракт: зафиксированы entry/trap/UART/syscall/exit; действующий `platform.S` перенесён в существующий `platform.saltic` и подключён к machine-mode VM.
- [x] Блок 4, host-проверка подтверждена владельцем: 5790/0.
- [x] Virt VM: размер RAM 128 MiB вычисляется во время исполнения; большой compile-time number ранее сворачивался в ноль.
- [x] Блок 4, virt ELF: один образ сохраняется после VM-проверки и запускается через `qemu-system-riscv32`; ожидаемый UART — `AB`.
- [x] Virt machine-mode VM подтверждена: 16/0; внешний QEMU пока остановлен таймаутом до первого UART-байта, включён точный trace.
- [x] Virt ELF подтверждён собственной VM и `qemu-system-riscv32`: 16/0, UART `AB`, успешный exit.
- [x] Общий runtime body отделён от host write/exit; обычный AST компонуется с существующей virt-платформой без дублирования меток.
- [x] Virt boot: QEMU входит строго в `0x80000000`; композиция ставит там trampoline к platform entry и затем продолжает `_start` после заменённого word.
- [x] Блок 4 подтверждён владельцем: virt-композиция с обычной Saltic-программой прошла 22/0 и внешний QEMU.
- [x] Путь к прямому ELF: размеры heap/BSS/p_memsz переведены на существующий `codec.Word`; квота 0xf0000000 кодируется без раздувания файла.
- [x] Toolchain пишет ELF из `machine.Program`; build различает переходный assembly stage-1 и обязательный direct ELF следующих стадий.
- [x] Wide heap/BSS подтверждены владельцем: `machine` и `vm-machine` прошли.
- [x] Direct bootstrap использует канонические 0xf0000000: переходные 512 MiB исчерпались при сборке нового ELF toolchain.
- [x] ELF-builder разделяет RX code/rodata и RW data/BSS; единый почти 4 GiB RWE-сегмент QEMU отвергал.
- [x] RX и RW разведены по разным 4 KiB страницам; пересекающиеся страницы двух PT_LOAD QEMU не загружал.
- [x] Direct ELF после записи получает executable bit; bootstrap проверяет исполняемость stage-2, stage-3 и канонической программы.
- [x] Большие compiler-блоки используют короткое обратное условие + `jal`; переходы дальше ±4 KiB больше не превращаются в нулевую инструкцию.
- [ ] Подтверждение дальних переходов отложено: `machine` попал в global OOM при почти полном swap; код теста не падал.
- [x] Дальние переходы подтверждены: `machine` — 5800/0.
- [x] Direct bootstrap подтверждён: stage-2 = stage-3 побайтно; прямой toolchain собрал канон — `bootstrap: ok`.
- [x] Блок 5: `just compile` и `just run` переведены в обязательный direct ELF; refresh сравнивает ELF fixed point без промежуточных `.s`.
- [x] Блок 5 закрыт: direct-only `just compile` подтверждён; повторный bootstrap fixed point дал hash `01aef6950c7e046df2fb12bded8cdd898241cac7fd3f0ad7e7cf8c497e286729`.
