# Saltic для Visual Studio Code

Расширение добавляет базовый визуальный слой Saltic:

- распознавание файлов `.saltic`;
- подсветку актуального синтаксиса через TextMate;
- парные скобки и автоматические отступы;
- иконку языка и файловую тему Saltic Icons;
- цветовую тему «Saltic Тема 1» (`themes/saltic-theme-1.json`) — как окно SalticIDE
  (`docs/site/IDE.html`): цвет несёт смысл, определения — жирным.

Установка ссылкой: `ln -s "$PWD" ~/.vscode/extensions/saltic.saltic-language-0.4.0`,
затем `Ctrl+K Ctrl+T` → «Saltic Тема 1».

## Локальная проверка

Открой каталог расширения в VS Code:

```bash
code workbench/vscode
```

Нажми `F5`, затем открой `os/target/qemu_virt/smoke.saltic` в окне Extension Development Host.

## Граница

Это лексическая подсветка: поле справа от `=` и переменную она не различает (`name = "pip"` в Box
красится как переменная) — это умеет только чекер. Диагностика, переход к определению и автодополнение появятся вместе с языковым сервером.
