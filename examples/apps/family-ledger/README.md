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
