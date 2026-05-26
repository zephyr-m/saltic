# Библиотечная архитектура

Этот документ фиксирует слои библиотек S.

Главная цель: не смешивать язык, bootstrap, C interop, стандартную библиотеку, системный слой, агентные инструменты и доменные знания.

## Слои

```text
S language core
  минимальный язык: skill, out, vars, control flow, expressions

c.*
  внешний C ABI и C ecosystem

host.*
  временные intrinsics текущей host-среды Racket

sys.*
  низкоуровневый системный слой S

agent.*
  агентные инструменты и runtime-паттерны

core.*
  фундаментальные инструменты рассуждения и предметные дисциплины

core.informatics.*
  инструменты вычислений, программирования и данных

core.informatics.std.*
  практический toolkit для обычного кода

core.engine.*
  общий фундамент для игр, симуляций, редакторов и CAD-like workflows

world.*
  поверхность будущей эмуляции физического мира

tool.*
  инструменты действия внутри world

std.*
  короткий alias к core.informatics.std.*, а не отдельный слой
```

## Правило

Каждый слой должен иметь понятный источник ответственности.

```text
c.*     не является std
host.*  не является std
sys.*   не является удобным пользовательским API
std.*   не является отдельной сущностью вне информатики
agent.* не должен быть частью базового языка
core.*  не должен быть runtime-заглушкой
core.engine.* не должен распасться на отдельные несовместимые CAD/game/simulation миры
world.* не должен сводиться к обычному GUI приложению
tool.* не должен быть просто набором editor commands без физической модели
```

## Миграционный путь

S может быть полезным до полной стандартной библиотеки за счёт C interop.

```text
v0.1  host.* через Racket bootstrap
v0.2  c.* как явный C interop
v0.3  sys.* как низкий слой S
v0.4  core.informatics.std.* как удобная оболочка
v0.x  std.* как короткий alias к core.informatics.std.*
own   sys/core.informatics.std получают native implementation под свою платформу
```

## Пример эволюции

```text
сейчас:
  host.file.read(path)

позже:
  c.fopen / c.fread / c.fclose

затем:
  sys.fs.read(path)

нормальный пользовательский API:
  core.informatics.std.file.read_text(path)

короткий alias:
  std.file.read_text(path)

дальше:
  core.informatics.std.file.read_text реализуется на S или через native sys backend
```

## std как часть информатики

`std` не должна быть отдельной магической областью.

Её концептуальное место:

```text
core.informatics.std
```

Почему:

- `std.io`, `std.file`, `std.str`, `std.mem`, `std.process` — это инструменты информатики;
- обычная программа работает с данными, файлами, процессами и памятью;
- S мыслит дисциплинами, поэтому стандартная библиотека должна жить внутри дисциплины вычислений;
- короткое имя `std.*` может быть удобным alias, но не отдельной сущностью языка.

Пример:

```text
реальное место:
  core.informatics.std.file.read_text(path)

короткое имя:
  std.file.read_text(path)
```

## Основной принцип

C interop и host intrinsics — это bootstrap-зависимости, а не идентичность языка.

S может использовать C, чтобы стать полезным быстро, но не обязан навсегда оставаться оболочкой над C.

## Engine как общий прикладной фундамент

`core.engine` — будущий слой для интерактивной физической сцены.

Он должен объединять то, что иначе распалось бы на отдельные домены:

```text
games
simulation
visual editors
CAD-like workflows
robotics sandbox
digital twin
```

`core.cad` сейчас не вводится как отдельный домен.

CAD-like workflows должны строиться поверх:

```text
core.engine
core.geometry
core.physics
core.units
core.numerics
core.graph
```

## World как целевая среда

Цель S — не только писать программы.

Цель — эмуляция физического мира, в которой можно действовать, наблюдать, измерять, собирать, симулировать и сохранять историю изменений.

```text
world -> act -> observe -> modify -> simulate -> persist
```

Код остаётся способом сделать действия точными и воспроизводимыми, но не обязан быть единственным интерфейсом.

Подробнее: [Physical world emulation](world.md).
