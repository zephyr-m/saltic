# Autonomy score

Этот документ фиксирует грубую, повторяемую оценку автономности S.

Это не точная метрика. Цель — понимать направление: где смысл уже живёт в S, а где Racket всё ещё является единственным носителем поведения.

## Current estimate

```text
S autonomy: about 40%
Racket dependency: about 60%
```

After std autonomy pass 1, this is still best described as `about 40%`, but it is closer to the upper side of that estimate because user-facing string algorithms started moving into S.

## Шкала

```text
0%    только документы и примеры синтаксиса
10%   parser/checker/runtime существуют, но всё поведение host-side
25%   можно писать и запускать полезные маленькие программы на S
40%   есть S std modules, bytecode contract и S-side VM semantics subset
60%   большая часть VM/std semantics живёт в S, Racket в основном host/reference
80%   parser/checker/compiler/tooling частично или в основном написаны на S
100%  S может поддерживать и собирать свой основной toolchain
```

## Текущая разбивка

```text
Source language usability          60%
Examples/tasks/docs                55%
S std modules                      35%
Bytecode contract                  55%
S-side VM semantics                35%
Runtime implementation             30%
Parser/checker/compiler            10%
Tooling                            20%
Host/protocol boundaries           25%
Self-hosting chain                  5%
```

Суммарно это даёт рабочую оценку около `40%`, потому что самые тяжёлые части пока остаются в Racket:

- parser;
- checker;
- compiler to bytecode;
- full VM/runtime;
- module loader;
- большинство `core.*`, `host.*`, `visual.*`, `world.*` boundary effects;
- test/tooling orchestration.

## Что уже добавляет автономность

- S-программы реально запускаются.
- Есть task pack и user examples.
- Часть `core` написана как S modules.
- Bytecode v0 описан как контракт.
- Racket VM уже не единственный conceptual target.
- Tiny VM на S исполняет bootstrap subset:
  - stack ops;
  - arithmetic and compare;
  - env/store/load;
  - `Group`;
  - `Box`;
  - `if`;
  - `drum`;
  - `switch`;
  - `rescue`;
  - local calls;
  - first boundary table for `core.io.println`.
- `core.str.contains` is now an S algorithm over `core.str.len/slice/eq`.
- `core.str.lines_count` is now an S algorithm over `core.str.len/at`.
- `core.str.is_empty/starts_with/ends_with` are now S algorithms over string primitives.
- `core.str.at/slice` are explicit minimal host primitives for future lexer/parser work.

## Что сильнее всего поднимет процент

Ближайшие приросты:

- расширить S-side `BoundaryTable` за пределы `core.io.println`;
- перенести `core.group.count/at` в explicit boundary model;
- move more `core.str.*` algorithms from host wrappers into S;
- сделать bytecode dump стабильным debugging artifact для большего числа examples;
- запускать больше canonical/user examples через VM;
- начать перенос маленьких compiler/runtime helper-ов в S.

Крупные приросты позже:

- parser fragments on S;
- checker fragments on S;
- module loader contract and partial S implementation;
- S toolchain wrapper;
- compiler self-hosting path.
