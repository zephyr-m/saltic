# Layers

Этот документ фиксирует границы между частями S.

Проблема роста проекта обычно не в размере, а в смешивании ответственности. Если язык, bootstrap, std и доменная логика живут в одном месте, проект расползается.

## Слои

```text
language core
  syntax, semantics, checker, formatter, runner-facing model

std
  пользовательская библиотека языка: строки, файлы, числа, ввод-вывод, время

bootstrap host
  временные low-level возможности текущего backend/runtime

toolchain
  parse, check, format, explain, run, tests

backend
  текущая платформа исполнения и будущие платформы
```

## Правило границ

- `language core` описывает то, без чего нельзя писать нормальный S-код.
- `std` описывает то, что должен видеть обычный пользователь.
- `bootstrap host` существует только пока язык не умеет сам обеспечить нужный минимум.
- `toolchain` не должен содержать доменную логику языка.
- `backend` не должен определять смысл языка.

## Что куда относится

- `syntax`, `out`, `drum`, `rescue`, `skill`, `program` -> `language core`
- `std.str`, `std.file`, `std.io`, `std.num` -> `std`
- `host.file.read`, `host.io.println`, `host.str.*` -> `bootstrap host`
- `just run`, `just check`, `just explain` -> `toolchain`
- Racket bootstrap -> `backend`

## Тест на правильное размещение

Если возможность нужна для одной программы и не переживёт смену backend, ей не место в ядре языка.

Если возможность нужна многим программам и должна быть доступна как обычный API, она должна двигаться в `std`.

Если возможность существует только потому, что текущий backend ещё слабый, она должна оставаться в bootstrap и иметь путь к удалению.

