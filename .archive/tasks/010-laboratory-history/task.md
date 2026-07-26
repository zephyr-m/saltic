# 010 laboratory history

Проверить лабораторию как последовательность наблюдаемых моментов.

Задача не добавляет синтаксис времени и не делает настоящий engine.

`moment` здесь является временной переменной теста. Она нужна только чтобы показать порядок переходов, пока ответственность за время ещё не перенесена в runtime/engine.

Идея:

- программа получает поток `Input`;
- `dispatch(lab, input)` применяет правила перехода;
- `observe(moment, input, lab)` показывает момент, причину и состояние;
- вывод читается как маленькая history.

Сцена:

- в лаборатории есть ключ;
- есть замок;
- есть дверь;
- игрок вставляет ключ;
- поворачивает ключ;
- открывает дверь.

Ожидаемый вывод:

```text
moment 1
input: InputKind.INSERT_KEY
lock: LockState.INSERTED
door: DoorState.CLOSED
moment 2
input: InputKind.TURN_KEY
lock: LockState.UNLOCKED
door: DoorState.CLOSED
moment 3
input: InputKind.OPEN_DOOR
lock: LockState.UNLOCKED
door: DoorState.OPEN
```
