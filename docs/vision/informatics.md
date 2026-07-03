# core.informatics

`core.informatics.*` — дисциплина вычислений внутри `core.*`.

Это место для инструментов программирования, данных, алгоритмов, памяти, файлов, процессов и сетей.

## Почему std здесь

Стандартная библиотека S не должна быть отдельной магической областью.

Она относится к информатике:

```text
core.informatics.std
```

Короткое имя `core.*` может появиться позже как alias:

```text
core.* == core.informatics.core.*
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
core.informatics.core.io
core.informatics.core.file
core.informatics.core.path
core.informatics.core.str
core.informatics.core.mem
core.informatics.core.cli
core.informatics.core.test
core.informatics.core.log
core.informatics.core.time
core.informatics.core.process
```

## Отношение к sys и c

```text
core.informatics.core.file.read_text(path)
  -> sys.fs.read(path)
  -> c.fopen/c.fread/c.fclose или native backend
```

`c.*` и `host.*` помогают bootstrap.

`sys.*` даёт низкий системный слой.

`core.informatics.core.*` даёт нормальный API для программ.
