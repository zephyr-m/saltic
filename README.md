<p align="center">
  <img src="masscot.jpg" alt="Saltic — маскот Candy Engine" width="720">
</p>

# Saltic

**Текущая версия: 1.10.0**

Saltic — самохостящийся системный язык: его активные парсер, чекер и компилятор
написаны на самом Saltic. В версии 1.0.0 достигнута стабильная самосборка —
результаты второго и третьего поколений компилятора совпадают побайтово.

Saltic делается одним автором для себя и своих агентов: автор принимает
решения, агенты их исполняют. Когда язык созреет, та же модель — владелец и
его агенты — станет доступна любому человеку.

История релизов находится в [CHANGELOG.md](CHANGELOG.md), каноничный номер
версии — в [VERSION](VERSION).

## Запуск

Окружение разработки зафиксировано через Nix:

```bash
nix --extra-experimental-features "nix-command flakes" develop
```

В открывшемся окружении используются обычные `just test`, `just run` и
`just package`; сами сценарии Saltic ничего о Nix не знают.

## Релиз

1. Поднять номер в `VERSION`, `README.md` и `CHANGELOG.md`.
2. Запустить `bash bootstrap/refresh.sh`: загрузочный компилятор получит имя
   новой версии и паспорт, прежний файл уйдёт.
3. Закоммитить готовый релиз.
4. Создать аннотированный тег с заголовком релиза:
   `git tag -a vX.Y.Z -m "Saltic X.Y.Z — название"`.
5. Отправить коммит и тег: `git push origin main --follow-tags`.

GitHub Actions сверит тег с `VERSION`, прогонит полный `just test`, возьмёт
описание из соответствующего раздела `CHANGELOG.md`, соберёт чистый SDK без
архива и чекпоинта и опубликует GitHub Release.

## Bootstrap

Зафиксированный компилятор лежит в [bootstrap/](bootstrap/) под именем
`saltic-<версия>-compiler-rv32i-linux.elf` с паспортом рядом. На x86-64
сборка и самосборка запускают его родную версию
`saltic-<версия>-compiler-x86_64-linux`, которую `bootstrap/` выводит сама:
результат побайтово тот же, что под QEMU, но в разы быстрее. `SALTIC_NATIVE=0`
возвращает запуск под QEMU. Обычные `just compile` и
`just run` не используют JavaScript. Старый JS-контур выведен из активного
проекта и в сборке или тестах не участвует.

## Лицензия

Saltic является закрытым программным обеспечением. Приватное тестирование
разрешено только людям, которым правообладатель явно предоставил доступ.
Условия: [русский текст](LICENSE.ru) и [английский перевод](LICENSE).

```saltic
use seed.io

AppName = "Saltic"

State = enum {
    READY,
    ACTIVE,
    FAILED,
}

Point = Box {
    x = 0,
    y = 0
}

Actor = Box {
    name = "agent",
    state = State.READY,
    energy = 100,
    position = Point {}
}

skill move(point, dx, dy) {
    out Point {
        x = point.x + dx,
        y = point.y + dy
    }
}

skill spend(actor, cost) {
    (cost > actor.energy) {
        out error.NotEnoughEnergy
    }

    out Actor {
        name = actor.name,
        state = State.ACTIVE,
        energy = actor.energy - cost,
        position = move(actor.position, 1, 0)
    }
}

skill show(actor) {
    (actor.state) {
        .READY => io.show("{actor.name} is ready"),
        .ACTIVE => io.show("{actor.name} is active"),
        .FAILED => io.show("{actor.name} needs rescue"),
    }

    io.show("energy: {actor.energy}")
    io.show("position: {actor.position.x},{actor.position.y}")
    out none
}

program() {
    @actor = Actor {
        name = "pip",
        energy = 42,
        position = Point { x = 2, y = 3 }
    }

    drum ([5, 7, 11]) {
        actor = spend(actor, beat) rescue |err| {
            io.show("failed: ", err)
            actor
        }
    }

    show(actor)
    out none
}
```
