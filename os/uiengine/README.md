# UIEngine

Закрытая библиотека компонентов в духе shadcn: на ней строятся и ОС, и
программы. Компоненты — забота движка, композиция — JTML, программе остаётся
смысл (`docs/OS-core.md`, «Интерфейс»).

Программа:

```
use os.uiengine
use путь.generated.app_jtml

program() {
    out uiengine.show(app_jtml.JTML)
}
```

`app.jtml` лежит рядом с программой, `tools/bake.py путь/app.jtml` вшивает его
в `generated/app_jtml.saltic`. Пример — `demo.saltic` + `demo/app.jtml`.

Пока рисует прямо в видеопамять через `graphics` цели UEFI
(`os/target/uefi_x86_64`).

| Модуль | Что делает |
|---|---|
| `../uiengine.saltic` | публичное лицо: `show(JTML)` |
| `jtml` | чтение JTML (`jtml/reader` — JSON) и свойства узла |
| `layout` | `column`, `row`, `card`, `spacer`: размеры, отступы (`padding`, `gap`), раскладка |
| `canvas` | цвета zinc, `Look` вариантов, скруглённые прямоугольники со сглаживанием, рамки |
| `fonts` | набор текста полутонами; начертания `REGULAR`, `MEDIUM`, `SEMIBOLD` (14 px), `SMALL` (12), `HEADING` (18) в `fonts/generated/` |
| `components` | компоненты по группам: `forms` (button, input, switch), `display` (badge, separator, progress, heading/title/text/muted/small, card) |
| `demo` | пример: экран из `demo/app.jtml` |

Инструменты (`tools/`):

- `fonts.py` — свой растеризатор TrueType без библиотек: `glyf`, `cmap`, составные глифы, вариации `gvar`/`avar` (жирность из вариативного Noto Sans), покрытие пикселя → `fonts/generated/`; `14 --weight 600 --preview out.png` — образец;
- `bake.py` — JTML → `generated/<имя>_jtml.saltic`.
