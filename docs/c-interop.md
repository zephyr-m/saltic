# C interop

`c.*` — будущий слой доступа к C ABI, libc и C ecosystem.

Это не стандартная библиотека S. Это foreign interface.

## Зачем нужен c.*

Пока S маленький, C может закрыть то, чего в языке ещё нет:

- ввод/вывод;
- файлы;
- память;
- строки и буферы;
- время;
- процессы;
- сокеты;
- системные вызовы;
- сторонние C-библиотеки.

## Желаемая форма

Черновой вариант:

```s
c.import "stdio.h"

skill main() {
    c.puts("hello from C")
    out none
}
```

Позже:

```s
c.import "stdlib.h"
c.import "string.h"

skill main() {
    @ptr = c.malloc(128)
    c.memset(ptr, 0, 128)
    c.free(ptr)
    out none
}
```

## Что нужно решить

C interop нельзя сделать честно без модели:

- headers;
- function signatures;
- C scalar types;
- pointers;
- arrays and buffers;
- structs;
- ownership;
- null;
- error handling;
- platform ABI differences.

## MVP

Первый безопасный MVP:

```text
c.import "stdio.h"
c.puts(text)
c.printf(format, ...)
c.strlen(text)
c.atoi(text)
```

Эти функции позволяют проверить мост без немедленного ввода полноценной модели памяти.

## Правило

Код через `c.*` живёт по правилам C ABI.

S может проверять базовые вещи, но не должен притворяться, что прямой C-вызов безопасен сам по себе.
