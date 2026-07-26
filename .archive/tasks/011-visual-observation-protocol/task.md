# 011 visual observation protocol

Проверить первый backend-neutral визуальный протокол.

Задача не добавляет HTML, canvas, браузер и renderer в язык.

Идея:

- S-программа описывает наблюдаемую инженерную сцену;
- runtime записывает visual trace;
- trace можно позже отдать любому backend: Linux preview, HTML, PNG, будущая S OS, framebuffer или свой display protocol.

Сцена:

- инженерный лист;
- сетка;
- квадратный бипирамидальный кристалл;
- вращение вокруг оси `y`;
- команда предъявить кадр.

Ожидаемый вывод:

```text
sheet engineering
grid 24
shape square_bipyramid crystal height 4 base 2 color cyan
motion rotate crystal y 1
present
```
