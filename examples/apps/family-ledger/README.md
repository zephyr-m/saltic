# Family Ledger

Первое маленькое приложение S для личной пользы: расчёт дневного финансового
состояния семьи по текстовому журналу.

Запуск:

```bash
just family-ledger
```

S-native UI trace:

```bash
just family-ledger-ui
```

Framebuffer-style preview image:

```bash
just family-ledger-frame
```

It writes:

```text
/tmp/family-ledger-ui.png
```

Temporary desktop window, with S logic under the hood:

```bash
just family-ledger-window
```

Interactive surface inside a temporary game-like world canvas:

```bash
just family-ledger-world
```

Прямой запуск через runner:

```bash
just run-file examples/apps/family-ledger/main.s examples/apps/family-ledger/ledger.txt
```

Программа читает минимальный формат:

```text
income  YYYY-MM-DD amount label
expense YYYY-MM-DD amount label
debt    YYYY-MM-DD amount label
```

Текущая версия специально маленькая: она показывает, что S уже может читать
файл, проходить по строкам через `drum` и счётчик, разбивать строки, парсить
числа и считать результат.
