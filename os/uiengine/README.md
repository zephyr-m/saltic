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
в `generated/app_jtml.saltic`.

Галерея всех компонентов — `demo.saltic`: двенадцать страниц из `demo/pages/*.jtml`
и тринадцатая «Железо» — её `demo/monitor.saltic` собирает при запуске из живых данных
(устройства PCI, скорость цикла по HPET), склеивая текст JTML;
(вшиваются `tools/bake.py demo/pages/*.jtml --into demo/generated`), листаются
клавиатурой Acer: ← → или Tab, цифры 1–0, Esc — выход к агенту: галерея рисует экран «Галерея закрыта» и
возвращает через `ExitData` причину выхода (скан-код, сколько страниц показано). Собрать с кучей
128 МБ и запустить через агента (`upload.py gallery.efi --run`).

Пока рисует прямо в видеопамять через `graphics` цели UEFI
(`os/target/uefi_x86_64`).

| Модуль | Что делает |
|---|---|
| `../uiengine.saltic` | публичное лицо: `show(JTML)` |
| `jtml` | чтение JTML (`jtml/reader` — JSON) и свойства узла |
| `layout` | блоки: `column`, `row`, `spacer`, `field`, `scroll`, `resizable` и рамки; размеры, `padding`, `gap` |
| `canvas` | цвета zinc, `Look` вариантов (default, secondary, outline, destructive, ghost) |
| `shapes` | сглаженные скругления, рамки, тени, линии любой толщины, затемнение, сохранение и возврат строк экрана (обрезка scroll area) |
| `fonts` | набор текста полутонами; начертания `REGULAR`, `MEDIUM`, `SEMIBOLD` (14 px), `SMALL` (12), `HEADING` (18) в `fonts/generated/` |
| `icons` | 25 иконок в духе lucide, 16 и 12 px, в `icons/generated/` |
| `components` | компоненты по группам (теги JTML ниже) |
| `demo` | галерея: 13 страниц компонентов, листание клавиатурой; `monitor` — живая страница «Железо» |

В JTML нет чисел раскладки — только токены дизайн-системы (`canvas`):

- отступы `gap`, `padding`: `none`, `xs` 4, `sm` 8, `md` 12, `lg` 16, `xl` 24, `2xl` 32;
- ширина `width`: `xs` 160, `sm` 240, `md` 320, `lg` 420, `xl` 560, `2xl` 720;
- высота `height`: `xs` 40, `sm` 120, `md` 200, `lg` 280, `xl` 560, `2xl` 720;
- `avatar.size`: `sm`, `md`, `lg`; `aspect.ratio`: `square`, `video`, `wide`, `portrait`;
  `skeleton.shape`: `line`, `circle`, `block`; `resizable.sizes`: доли `"1/3"`, `"2/3"`.

Числами остаются только данные: `value`, `year`, `month`, `today`, `rows`, `length`,
`start`, `highlight`, `sort`.

Теги JTML:

- `buttons` — `button` (variant, icon, disabled), `toggle`, `toggle-group`, `button-group`;
- `fields` — `input` (icon, action), `textarea`, `select`, `input-otp`, `combobox`, `label`;
- `choices` — `checkbox`, `radio`, `switch`, `slider`;
- `display` — `heading`, `title`, `text`, `muted`, `small`, `kbd`, `badge`, `separator`, `progress`, `icon`, `alert`, `avatar`, `skeleton`, `aspect`, `spinner`, `empty`, `table`;
- `navigation` — `tabs`, `breadcrumb`, `pagination`, `accordion`, `collapsible`, `item`, `sidebar`, `navigation-menu`;
- `overlays` — `tooltip`, `menu` (dropdown и context menu), `menubar`, `command`;
- `data` — `calendar`, `date-picker`, `chart` (bar, line, area), `data-table`, `carousel`, `stat`, `sparkline`;
- `editor` — `code`: блок кода с подсветкой Saltic (Noto Sans Mono 13), номера строк, `title`, `highlight`, `start`; `tree`: дерево файлов (`open`, `active`, вложенные `children`);
- рамки — `card`, `popover` (и hover card), `dialog` (и alert dialog), `sheet`, `drawer`, `toast`, `window` (окно ОС с заголовком `title`);
  слой поверх страницы — свойство корня `"overlay"`: dialog и sheet и drawer затемняют страницу.

Инструменты (`tools/`):

- `icons.py` — иконки: ломаные на сетке 24 → покрытие по расстоянию до отрезков;
- `fonts.py` — свой растеризатор TrueType без библиотек: `glyf`, `cmap`, составные глифы, вариации `gvar`/`avar` (жирность из вариативного Noto Sans), покрытие пикселя → `fonts/generated/`; `14 --weight 600 --preview out.png` — образец;
- `bake.py` — JTML → `generated/<имя>_jtml.saltic`.
