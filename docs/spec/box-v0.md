# Box v0

Этот документ фиксирует целевую форму `Box v0`.

`Box v0` реализован в parser/checker/runtime как минимальный структурированный value container.

## Назначение

`Box` — форма состояния вещи.

Он нужен, чтобы описывать структурированное состояние без выбора между `struct`, `class`, `record`, `object`, `map` и другими историческими слоями.

`Box` должен:

- уменьшать число решений для человека и агента;
- читатьcя как цифровая бумага;
- описывать состояния, параметры, сцены и модели;
- не превращаться в объектную систему.

Для физической модели `Box` не является всей вещью как identity во времени.

Подробнее: [Time and State v0](time-state-v0.md).

Поведение объекта не живёт внутри `Box`.

`Box` описывает форму состояния.
Object skill calls описаны отдельно: [Object Skill Call v0](object-skill-call-v0.md).

## Объявление

```s
Point = Box {
    x = 0
    y = 0
}
```

Поля внутри `Box` пишутся без `@`.

Причина: `@` обозначает локальный шаг вычисления, а поле `Box` описывает форму данных.

## Создание

```s
@point = Point {
    x = 5
    y = 4
}
```

Пустое создание использует значения по умолчанию:

```s
@origin = Point {}
```

Вложенные `Box` создаются так же:

```s
Camera = Box {
    position = Point {}
    radius = 0
}
```

## Доступ к полям

```s
point.x
point.y
camera.position.x
```

Доступ через точку должен читаться одинаково для человека и агента.

## Defaults

Каждое поле v0 должно иметь значение по умолчанию.

```s
Object = Box {
    name = ""
    position = Point {}
}
```

При создании можно указать часть полей. Остальные берутся из defaults.

Неизвестные поля должны быть ошибкой checker.

## Mutation

`Box v0` не вводит изменение поля.

Не поддерживается:

```s
point.x = 10
```

Если нужно новое состояние, создаётся новый `Box`:

```s
@next = Point {
    x = point.x + 1
    y = point.y
}
```

Это сохраняет простую модель состояния:

```text
old state -> action -> new state
```

## Render example

Канонический пример лежит в:

```text
tasks/004-render-frame/solution.s
```

Ключевая форма:

```s
Point = Box {
    x = 0
    y = 0
}

Camera = Box {
    position = Point {}
    radius = 0
}

Object = Box {
    name = ""
    position = Point {}
}

skill visibility(object, camera) {
    @dx = object.position.x - camera.position.x
    @dy = object.position.y - camera.position.y
    @distance = dx * dx + dy * dy
    @limit = camera.radius * camera.radius
    (distance < limit) {
        out Visibility.VISIBLE
    }
    out Visibility.HIDDEN
}
```

## Не входит в v0

- методы внутри `Box`;
- наследование;
- interfaces/traits;
- private/public;
- dynamic fields;
- field mutation;
- references/pointers;
- arrays;
- recursive Box;
- computed fields;
- constructors;
- layout/alignment/ABI;
- optional fields без явного решения по `none`.

## Открытые вопросы

- `Box v0` является value container; когда и как появится reference semantics, не решено.
- Как `Box` связан с identity-object во времени.
- Нужно ли требовать все поля при создании или defaults достаточно.
- Как `none` взаимодействует с полями.
- Как `Box` перейдёт в системный слой layout/ABI.
- Нужна ли отдельная форма обновления вроде `with`, если явное создание нового значения станет слишком тяжёлым.
