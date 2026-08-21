# Saltic

**Текущая версия: 1.1.1**

Saltic — самохостящийся системный язык: его активные парсер, чекер и компилятор
написаны на самом Saltic. В версии 1.0.0 достигнута стабильная самосборка —
результаты второго и третьего поколений компилятора совпадают побайтово.

История релизов находится в [CHANGELOG.md](CHANGELOG.md), каноничный номер
версии — в [VERSION](VERSION).

## Релиз

1. Поднять номер в `VERSION`, `README.md` и `CHANGELOG.md`.
2. Закоммитить готовый релиз.
3. Создать аннотированный тег с заголовком релиза:
   `git tag -a vX.Y.Z -m "Saltic X.Y.Z — название"`.
4. Отправить коммит и тег: `git push origin main --follow-tags`.

GitHub Actions сверит тег с `VERSION`, прогонит полный `just test`, возьмёт
описание из соответствующего раздела `CHANGELOG.md` и опубликует GitHub Release.

## Bootstrap

Зафиксированный [bootstrap/compiler.elf](bootstrap/compiler.elf) запускается
через QEMU и собирает актуальный тулчейн из `s2/`. Обычные `just compile` и
`just run` не используют JavaScript. Старый JS-тулчейн сохранён как эталон и
доступен через `just js-compile` и `just js-run`.

## Лицензия

Saltic является закрытым программным обеспечением. Приватное тестирование
разрешено только людям, которым правообладатель явно предоставил доступ.
Условия: [русский текст](LICENSE.ru) и [английский перевод](LICENSE).

```s
use core

AppName = "Saltic"

State = enum {
    READY,
    ACTIVE,
    FAILED,
}

Point = Box {
    x = 0
    y = 0
}

Actor = Box {
    name = "agent"
    state = State.READY
    energy = 100
    position = Point {}
}

skill move(point, dx, dy) {
    out Point {
        x = point.x + dx
        y = point.y + dy
    }
}

skill spend(actor, cost) {
    (cost > actor.energy) {
        out error.NotEnoughEnergy
    }

    out Actor {
        name = actor.name
        state = State.ACTIVE
        energy = actor.energy - cost
        position = move(actor.position, 1, 0)
    }
}

skill show(actor) {
    (actor.state) {
        .READY => core.io.show(actor.name, " is ready"),
        .ACTIVE => core.io.show(actor.name, " is active"),
        .FAILED => core.io.show(actor.name, " needs rescue"),
    }

    core.io.show("energy: ", actor.energy)
    core.io.show("position: ", actor.position.x, ",", actor.position.y)
    out none
}

program() {
    @actor = Actor {
        name = "pip"
        energy = 42
        position = Point { x = 2 y = 3 }
    }

    @costs = [5, 7, 11]
    @index = 0

    drum (core.group.count(costs)) {
        @cost = core.group.at(costs, index)
        actor = spend(actor, cost) rescue |err| {
            core.io.show("failed: ", err)
            actor
        }
        index = index + 1
    }

    show(actor)
    out none
}
```
