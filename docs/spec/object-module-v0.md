# Object module v0

`Object module v0` фиксирует первый способ вынести объект в отдельный `.s` лист.

Объектный модуль хранит рядом:

- состояния объекта;
- форму объекта через `Box`;
- события или команды объекта;
- skills, которые описывают допустимые реакции.

## Файл объекта

```text
objects/player.s
```

```s
PlayerState = enum {
    IDLE,
    MOVED,
    LOCKED,
}

Point = Box {
    x = 0
    y = 0
}

Player = Box {
    name = "PLAYER"
    state = PlayerState.IDLE
    position = Point {}
}

Move = Box {
    dx = 0
    dy = 0
}

skill react(player, move) {
    (player.state == PlayerState.IDLE) {
        out Player {
            name = player.name
            state = PlayerState.MOVED
            position = Point {
                x = player.position.x + move.dx
                y = player.position.y + move.dy
            }
        }
    }
    out player
}
```

## Import

```s
use objects.player
```

`use objects.player` ищет файл:

```text
objects/player.s
```

относительно файла, где написан import.

## Канон v0

В v0 импортированный файл добавляет top-level объявления в программу:

- `enum`;
- `Box`;
- `skill`;
- constants;
- `use core`, если он нужен модулю.

Вызов skill пока остаётся обычным:

```s
@next = react(player, move)
```

Не вводится:

```s
@next = player.react(move)
```

## Не входит в v0

- private/public;
- aliases;
- wildcard imports;
- package manager;
- methods;
- namespaced access вроде `player.react`;
- отдельный синтаксис `object`;
- автоматическое владение состоянием;
- запрет на прямое создание `Player`.

## Причина

Этот шаг нужен, чтобы объект перестал быть куском одного большого файла.

`Box` описывает форму вещи.
`Group` описывает группу вещей.
`Object module` описывает лист, где у вещи есть состояния, события и реакции.
