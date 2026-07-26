# core.engine

`core.engine` — будущий общий фундамент для интерактивной физической сцены.

Он не является просто игровым движком в обычном смысле. Это нижний слой будущей эмуляции физического мира.

Подробнее о целевой среде: [Physical world emulation](world.md).

Это не отдельный CAD-домен. Это более общий слой, на котором могут строиться:

- игры;
- физические симуляции;
- визуальные редакторы;
- CAD-like workflows;
- robotics sandbox;
- digital twin;
- интерактивные агентные среды.
- физический мир S.

## Почему не core.cad сейчас

CAD-подобные инструменты не должны появляться как изолированная область раньше фундамента.

Им всё равно нужны:

- математика;
- геометрия;
- единицы измерения;
- численные методы;
- constraints;
- scene graph;
- физика;
- материалы;
- mesh/solid representation;
- editor tooling.

Если сначала сделать отдельный `core.cad`, есть риск получить вторую параллельную систему рядом с игровым/физическим движком.

Поэтому правило v0.x:

```text
core.cad пока не вводим.
CAD-like workflows строятся поверх core.engine + core.geometry + core.physics.
```

## Зависимости

`core.engine` должен опираться на фундаментальные дисциплины:

```text
core.math
core.units
core.geometry
core.numerics
core.graph
core.physics
core.informatics
```

## Черновая карта

```text
core.engine.scene
core.engine.transform
core.engine.mesh
core.engine.material
core.engine.constraint
core.engine.collision
core.engine.rigid_body
core.engine.render
core.engine.input
core.engine.asset
core.engine.editor
```

## CAD-like workflows

CAD-подобные функции должны быть режимом или набором инструментов поверх engine:

```text
core.engine.editor.sketch
core.engine.constraint.distance
core.engine.constraint.parallel
core.engine.mesh.extrude
core.engine.scene.object
```

Позже можно будет выделить удобный facade, если практика покажет, что он нужен. Но фундамент должен оставаться общим.

## Основной принцип

Один движковый фундамент лучше, чем отдельные несовместимые миры для игр, симуляций, CAD и редакторов.

`core.engine` должен вести к среде, где основной цикл работы выглядит так:

```text
world -> act -> observe -> modify -> simulate
```

А не только:

```text
code -> run -> output
```
