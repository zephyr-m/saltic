# Rocket Toolchain

Rocket — первый носитель и toolchain для S.

Ранние версии S будут жить на Rocket. Это значит, что парсер, форматтер, checker, примеры, документация и первые backend-эксперименты должны появиться в Rocket раньше, чем S станет самостоятельным языком.

## Роль Rocket

Rocket — это не просто утилита сборки.

Rocket должен быть расширением памяти для человека и ограничителем выбора для агента.

Он должен помогать писать без интернета:

```bash
rocket help loops
rocket explain rescue
rocket example tcp-server
rocket new firmware-blink
rocket docs offline
```

## Цель

Rocket должен стать единой точкой входа в проект S.

## Черновые команды

```text
rocket run             Запустить программу
rocket build           Собрать проект
rocket test            Запустить тесты
rocket format          Отформатировать код
rocket lint            Проверить стиль и ошибки
rocket check           Проверить код без сборки
rocket parse           Показать результат парсинга
rocket add <pkg>       Добавить пакет
rocket remove <pkg>    Удалить пакет
rocket docs            Сгенерировать документацию
rocket new <name>      Создать проект
rocket example <name>  Показать локальный пример
rocket explain <topic> Объяснить конструкцию языка
```

## Компоненты

```text
parser
formatter
checker
linter
debugger
builder
backend
package manager
docs generator
offline cookbook
```

## Первая цель Rocket

Не нужно начинать с полноценного компилятора.

Первый полезный MVP:

```text
rocket parse examples/basic.s
rocket format examples/basic.s
rocket check examples/basic.s
```

Если S нельзя стабильно парсить, форматировать и проверять, backend писать рано.

## Черновой pipeline

```text
source (.s files)
  -> parser
  -> AST
  -> checker
  -> IR
  -> backend
  -> target
```

## Целевые платформы

Черновые targets:

- Linux;
- Windows;
- macOS;
- WASM;
- ESP32;
- собственная ISA.

## Открытые вопросы

- На каком языке пишется первый Rocket?
- Rocket сначала компилирует S напрямую или транслирует ранний S в C/Zig?
- Как выглядит IR?
- Как выглядит manifest пакета?
- SPM живёт внутри Rocket или рядом с ним?
- Как Rocket будет помогать агентам не выбирать неправильный путь?
