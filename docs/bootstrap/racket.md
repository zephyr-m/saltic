# Racket Bootstrap

Racket — первая bootstrap-платформа для S.

Это не финальная цель языка. Это практический способ быстро вырастить S, пока собственной архитектуры ещё нет.

## Почему Racket

Racket хорошо подходит для language-oriented programming:

- можно создавать новые языки через `#lang`;
- есть мощная macro-система;
- удобно строить DSL;
- удобно экспериментировать с parser/AST/checker;
- можно быстро получить рабочую лабораторию языка без написания backend с первого дня.

Для S это важно: сначала нужно доказать синтаксис и семантику, а уже потом думать о машинном коде и собственной ISA.

## Роль Racket

Racket должен помочь создать первую живую версию S:

```text
.s source
  -> parser
  -> AST
  -> checker
  -> formatter
  -> interpreter / early runtime
```

На этом этапе S может исполняться внутри Racket или транслироваться в промежуточную форму. Это нормально: ранняя цель — не производительность, а проверка языка.

## Что важно получить первым

Первый MVP:

```text
parse examples/basic.s
format examples/basic.s
check examples/basic.s
run examples/basic.s
```

До этого писать полноценный компилятор рано.

## Долгосрочный путь

Черновой путь развития:

```text
S syntax
  -> Racket parser
  -> AST
  -> checker
  -> interpreter
  -> IR
  -> C/Zig or native backend
  -> backend под собственную ISA
```

Собственная архитектура остаётся финальной целью, но она не должна блокировать первые версии S.

## Связь с toolchain

На раннем этапе команды могут быть простыми Racket-скриптами:

```bash
racket tools/parse.rkt examples/basic.s
racket tools/check.rkt examples/basic.s
racket tools/format.rkt examples/basic.s
```

Позже вокруг этого может появиться единая CLI-утилита S.

## Текущие команды

Сейчас команды обёрнуты в `justfile`.

```bash
just
just parse
just check
just format
just run
just test
just example
just docs
```

Заглушка под следующий этап:

```bash
just explain
```

Полный список зафиксирован в [Командах](../tooling/commands.md).

## Открытые вопросы

- Делать S как `#lang s` или как набор Racket tools вокруг `.s` файлов?
- Какая грамматика нужна для первого parser?
- Исполнять S через интерпретатор или транслировать в Racket AST?
- Когда вводить IR?
- Нужен ли ранний C/Zig backend до собственной ISA?
- Как сохранить простоту языка, если Racket позволяет делать почти всё?
