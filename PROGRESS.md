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
