# core.informatics

`core.informatics.*` — дисциплина вычислений внутри `core.*`.

Это место для инструментов программирования, данных, алгоритмов, памяти, файлов, процессов и сетей.

## Почему core здесь

Стандартная библиотека S не должна быть отдельной магической областью.

Она относится к информатике:

```text
core.informatics.base
```

Короткое имя `core.*` может появиться позже как alias:

```text
core.* == core.informatics.base.*
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
core.informatics.base
```

## core.informatics.base

Практический toolkit для обычных программ:

```text
core.informatics.base.io
core.informatics.base.file
core.informatics.base.path
core.informatics.base.str
core.informatics.base.mem
core.informatics.base.cli
core.informatics.base.test
core.informatics.base.log
core.informatics.base.time
core.informatics.base.process
```

## Отношение к sys и c

```text
core.informatics.base.file.read_text(path)
  -> sys.fs.read(path)
  -> c.fopen/c.fread/c.fclose или native backend
```

`c.*` и `host.*` помогают bootstrap.

`sys.*` даёт низкий системный слой.

`core.informatics.base.*` даёт нормальный API для программ.
