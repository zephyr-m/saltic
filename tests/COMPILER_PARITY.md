# Сравнение компиляторов

Команда `bash tests/4-compiler-parity.sh` сравнивает host-компилятор
`js/3-compiler.js` и компилятор на Saltic из `s2/compiler.saltic`.

Зафиксированный интерфейс self-hosted слоя:

```s
skill compile(ast) {
    out assembly
}
```

Тест требует точного совпадения RV32I assembly, затем собирает оба ELF и
сравнивает их поведение на `canonical.saltic`.

Все промежуточные результаты сохраняются в `.cache/build/compiler-parity/`:

- `bootstrap/compiler.saltic` — parser, checker и compiler с общей точкой входа;
- `bootstrap/compiler-rv32i.s` — исходный assembly bootstrap-компилятора;
- `bootstrap/compiler-large-heap.s` — его версия с 48-МБ рабочим heap;
- `bootstrap/compiler.elf` — исполняемый self-hosted компилятор;
- `expected/` — assembly и ELF от host-компилятора;
- `actual/` — assembly и ELF от Saltic-компилятора;
- `run-host/` и `run-saltic/` — stdout и созданные программами файлы;
- `diff/` — различия assembly, stdout и выходных файлов.

Увеличенный heap применяется только к тяжёлому bootstrap-компилятору. ELF,
которые он создаёт для обычных Saltic-программ, сохраняют стандартный heap
16 МБ и должны дословно совпадать с результатом host-компилятора.
