# 004 render frame

Смоделировать один текстовый кадр цифрового мира.

Это не настоящий графический renderer. Это первый render task: сцена, камера, объекты и проверка видимости.

Решение использует `Box v0`: сцену, камеру и объекты нужно описать как формы вещей.

Даны значения внутри программы:

```text
width = 20
height = 10
camera_x = 0
camera_y = 0
radius = 8

PLAYER at 5,4
LIGHT at 2,2
WALL at 10,4
```

Нужно:

- вывести размер кадра;
- вывести позицию камеры;
- для каждого объекта посчитать, попадает ли он в радиус видимости камеры;
- вывести объект как `visible` или `hidden`.

Видимость считается через квадрат расстояния:

```text
dx = x - camera_x
dy = y - camera_y
distance = dx * dx + dy * dy
visible if distance < radius * radius
```

Ожидаемый вывод:

```text
frame: 20x10
camera: 0,0
PLAYER visible at 5,4
LIGHT visible at 2,2
WALL hidden at 10,4
```
