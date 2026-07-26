# 012 actor fabric pulse

Проверить минимальное вычисление через взаимодействие акторов.

Задача не добавляет `actor.*`, `fabric.*` или новые runtime intrinsics.

Идея:

- есть два актора `A` и `B`;
- `A` получает leaflet `PING`;
- `A` меняет локальное состояние и отправляет `PULSE` для `B`;
- `B` получает `PULSE` и становится `ACTIVE`;
- вывод показывает моменты, получение сообщения, отправку сообщения и итоговое состояние.

Это первый runnable-срез канона:

```text
computation = interaction over time
```

Ожидаемый вывод:

```text
moment 1
actor A received LeafletKind.PING
actor A sent LeafletKind.PULSE to B
actor A state ActorAState.SENT
moment 2
actor B received LeafletKind.PULSE
actor B state ActorBState.ACTIVE
```
