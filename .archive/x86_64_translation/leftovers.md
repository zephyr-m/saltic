# Перевод RV32I → x86-64 — на пенсии с 06.11.2026

Решение автора (Q-012): перевод уходит, когда родной x86-64 на 64 битах
сойдётся с RV64 по выводу тестов. Сошёлся на шаге 4, UEFI — на шаге 5.

Здесь лежит всё, что было переводом:

- `x86_64_translation.saltic`, `x86_64_translation/` — сам бэкенд (переводчик
  команд RV32I, кодировщик, ELF64, PE32+, заглушки syscall Linux и UEFI).
  Платформа `stub.Uefi` продолжила жить как `compiler/platform/uefi.saltic`.
- `oracle.sh` — сверка вывода перевода и родного x86-64 (из `workbench/`).
- Ниже — куски, которые жили внутри общих файлов, дословно.

Цели были `x86_64-translation` и `x86_64-uefi-translation`.

## soul/seed/selfhost/toolchain.saltic

`build_machine` был с параметром `firmware` (платформа `stub.Uefi` для
перевода); остался без него, только для rv32i.

```saltic
skill build_machine(ast, heap_size, far_calls, firmware) {
    @executor = rv32i.Executor { far_calls = far_calls }
    (firmware == yes) { out compiler.compile_machine(ast, heap_size, executor, stub.Uefi {}) }
    out compiler.compile_machine(ast, heap_size, executor, linux.Linux {})
}

skill write_native(ast, heap_size, output_path, firmware) {
    @machine = build_machine(ast, heap_size, no, firmware)
    io.show("toolchain: перевожу в x86-64 ", output_path)
    pick {
        (firmware == yes) {
            x86_64_translation.write_uefi(output_path, machine) rescue |failure| {
                show(errors.near_calls_failed())
                @far = build_machine(ast, heap_size, yes, yes)
                x86_64_translation.write_uefi(output_path, far) rescue |again| {
                    show(errors.far_calls_failed())
                    out error.WriteFailed
                }
                out none
            }
        }
        {
            x86_64_translation.write(output_path, machine) rescue |failure| {
                show(errors.near_calls_failed())
                @far = build_machine(ast, heap_size, yes, no)
                x86_64_translation.write(output_path, far) rescue |again| {
                    show(errors.far_calls_failed())
                    out error.WriteFailed
                }
                out none
            }
        }
    }
    out none
}
```

Выбор цели в `build`:

```saltic
    (target == "x86_64-translation") { out write_native(checked.tree, heap_size, output_path, no) }
    (target == "x86_64-uefi-translation") { out write_native(checked.tree, heap_size, output_path, yes) }
```

## tests/run.sh

```bash
test_uefi_translation() {
    SALTIC_TARGET=x86_64-uefi-translation SALTIC_UEFI_DIR="$work/uefi-translation" bash os/target/uefi_x86_64/build.sh
    SALTIC_UEFI_DIR="$work/uefi-translation" bash os/target/uefi_x86_64/run.sh --check
}
```

Вызовы: `native-translation) SALTIC_NATIVE_TARGET=x86_64-translation test_native ;;`,
`uefi-translation) test_uefi_translation ;;`; `native-translation` — в наборе
`all`, `uefi-translation` — в `platforms`. Третья цель `x86_64-translation`
была в `test_edges` и `test_platform`.

## bootstrap/refresh.sh — оракул самосборки

```bash
echo "bootstrap refresh: оракул — stage-1 собирает stage-2 переводом (x86_64-translation), тот собирает rv32i"
stage "$work/stage-1/toolchain" x86_64-translation "$work/stage-2/toolchain-translation"
stage "$work/stage-2/toolchain-translation" rv32i "$work/stage-3/toolchain-translation.elf"
cmp "$work/stage-3/toolchain.elf" "$work/stage-3/toolchain-translation.elf"
echo "bootstrap refresh: перевод даёт те же байты rv32i, что родной x86-64"
```

## workbench

- `hosts.sh`: шаг `"x86_64-translation all"` — все тесты компилятором,
  собранным переводом.
- `same.sh`: третья цель `x86_64-translation` в сверке полки и stage-1.
