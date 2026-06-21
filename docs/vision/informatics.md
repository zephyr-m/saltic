# core.informatics

`core.informatics.*` — дисциплина вычислений внутри `core.*`.

Это место для инструментов программирования, данных, алгоритмов, памяти, файлов, процессов и сетей.

## Почему std здесь

Стандартная библиотека S не должна быть отдельной магической областью.

Она относится к информатике:

```text
core.informatics.std
```

Короткое имя `std.*` может появиться позже как alias:

```text
std.* == core.informatics.std.*
```

## Черновая карта

```text
core.informatics.algorithm
core.informatics.data
core.informatics.memory
core.informatics.file
core.informatics.process
core.informatics.network
core.informatics.encoding
core.informatics.security
core.informatics.std
```

## core.informatics.std

Практический toolkit для обычных программ:

```text
core.informatics.std.io
core.informatics.std.file
core.informatics.std.path
core.informatics.std.str
core.informatics.std.mem
core.informatics.std.cli
core.informatics.std.test
core.informatics.std.log
core.informatics.std.time
core.informatics.std.process
```

## Отношение к sys и c

```text
core.informatics.std.file.read_text(path)
  -> sys.fs.read(path)
  -> c.fopen/c.fread/c.fclose или native backend
```

`c.*` и `host.*` помогают bootstrap.

`sys.*` даёт низкий системный слой.

`core.informatics.std.*` даёт нормальный API для программ.
