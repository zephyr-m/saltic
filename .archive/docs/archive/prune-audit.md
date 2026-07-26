# S Repository Prune Audit

Временная таблица перед чисткой репозитория.

## Выполнено

- `docs/hardware/` перенесён в `archive/vision/hardware/`.
- `docs/visual/` перенесён в `archive/vision/visual/`.
- сгенерированный `tools/compiled/` удалён и добавлен в ignore.
- дублирующий `docs/start/layers.md` удалён.
- `docs/start/task-lessons.md` перенесён в `archive/docs/start/`.

Правило: ничего не удалять по ощущению. Сначала определить роль, источник истины и цену удаления.

## Решения

```text
KEEP      оставить в активной системе
MERGE     слить с другим источником истины
ARCHIVE   сохранить вне активного пути языка
DELETE    удалить после проверки зависимостей
GENERATED удалить и добавить в ignore
REVIEW    нужен отдельный разбор
```

## Критерий одного пути

Для каждой задачи должен остаться один канонический путь:

```text
одна конструкция
→ одна семантика
→ один runtime path
→ один пример
→ один тест
→ один источник документации
```

## Корень

| Path | Role | Source of truth | Used by code | Action | Reason |
|---|---|---|---|---|---|
| `README.md` | вход в язык | yes | no | KEEP | публичная точка входа |
| `justfile` | команды проекта | yes | yes | KEEP | единый путь запуска проверки |
| `drafts/` | сырые материалы | no | no | ARCHIVE | не должен конкурировать со spec |
| `old/` | исторические материалы | no | no | ARCHIVE | не является активной правдой |
| `dist/*.vsix` | собранные расширения | no | no | GENERATED | собирать командой, не хранить результат |
| `tools/compiled/` | Racket cache | no | no | GENERATED | удалить из Git и добавить в ignore |
| `.vscode/` | локальная интеграция | yes | no | KEEP | часть developer experience |

## Документация: vision

| Path | Role | Source of truth | Action | Reason |
|---|---|---|---|---|
| `docs/vision/philosophy.md` | философия языка | yes | KEEP | основа решений |
| `docs/vision/README.md` | индекс vision | yes | KEEP | навигация |
| `docs/vision/non-goals.md` | ограничения | yes | KEEP | защищает от разрастания |
| `docs/vision/agent.md` | агентная цель | yes | KEEP | ключевой сценарий Saltic |
| `docs/vision/core.md` | карта будущих core | partial | MERGE | часть можно перенести в layers |
| `docs/vision/informatics.md` | будущий домен | no | ARCHIVE | не нужен для v0.1 |
| `docs/vision/engine.md` | будущий engine | no | ARCHIVE | не нужен для v0.1 |
| `docs/vision/world.md` | физический мир | no | ARCHIVE | vision, не текущая семантика |
| `docs/vision/programmable-matter.md` | дальнее vision | no | ARCHIVE | не влияет на текущий язык |
| `docs/vision/digital-paper.md` | отдельная идея | no | ARCHIVE | не влияет на текущий язык |
| `docs/vision/ideal-system.md` | идеальная система | partial | MERGE | проверить дублирование philosophy |

## Документация: start

| Path | Role | Source of truth | Action | Reason |
|---|---|---|---|---|
| `docs/start/v0.1-core.md` | граница текущего core | yes | KEEP | текущий scope |
| `docs/start/practice-first.md` | критерии практической пользы | yes | MERGE | объединить с v0.1-core |
| `docs/start/runtime-freeze.md` | правила runtime | yes | KEEP | защита от роста surface |
| `docs/start/foundation.md` | общая модель языка | partial | MERGE | разделить между current/runtime |
| `docs/start/layers.md` | слои | partial | MERGE | объединить с architecture/layers |
| `docs/start/libraries.md` | библиотечная модель | yes | KEEP | важный Candy-принцип |
| `docs/start/roadmap.md` | большая дорожная карта | partial | MERGE | оставить одну roadmap |
| `docs/start/self-hosting-roadmap.md` | self-hosting | partial | MERGE | объединить с roadmap |
| `docs/start/today.md` | текущий план | no | DELETE | быстро устаревает |
| `docs/start/task-lessons.md` | пересказ задач | partial | MERGE | источник должен быть `tasks/` |
| `docs/start/autonomy-score.md` | оценка автономности | no | ARCHIVE | метрика без канонической семантики |

## Документация: spec

| Path | Role | Source of truth | Action | Reason |
|---|---|---|---|---|
| `docs/current/grammar.md` | parser grammar | yes | KEEP | один источник формы |
| `docs/current/syntax.md` | user syntax | yes | KEEP | один источник пользовательского языка |
| `docs/current/types.md` | type/value model | yes | KEEP | требует чистки противоречий |
| `docs/current/errors.md` | error semantics | yes | KEEP | ключевая часть Candy API |
| `docs/current/modules.md` | module semantics | yes | KEEP | один путь импорта |
| `docs/current/checker.md` | checker contract | yes | KEEP | executable rule |
| `docs/current/runtime.md` | runtime contract | yes | KEEP | runtime source |
| `docs/current/effects-inventory-v0.md` | effects registry | yes | KEEP | machine-readable contract |
| `docs/current/core-v0.1.md` | core API | yes | KEEP | текущий user-facing surface |
| `docs/current/box-v0.md` | Box | yes | KEEP | текущий canonical value model |
| `docs/current/group-v0.md` | Group | yes | KEEP | текущая collection model |
| `docs/current/time-state-v0.md` | time/state | partial | REVIEW | может быть глубже текущего v0 |
| `docs/current/bytecode-v0.md` | bytecode contract | yes | KEEP | backend contract |
| `docs/current/vm-step-v0.md` | VM stepping / self-hosting transfer | yes | KEEP | конкретный контракт переноса инструкций |
| `docs/current/s-machine-v0.md` | machine model / observable execution | yes | KEEP | архитектурная модель исполнения, не дубликат step-контракта |
| `docs/current/visual-observation-v0.md` | visual protocol | no | ARCHIVE | будущий protocol, не core v0 |
| `docs/current/ui-native-v0.md` | native UI | no | ARCHIVE | слишком ранний слой |
| `docs/current/object-module-v0.md` | local object import | yes | KEEP | реализация локального import-пути |
| `docs/current/object-skill-call-v0.md` | object interaction model | partial | REVIEW | отдельный слой поведения объектов, не смешивать с import |
| `docs/current/README.md` | spec index | yes | KEEP | навигация |

## Документация: bootstrap, hardware, visual

| Path | Role | Action | Reason |
|---|---|---|---|
| `docs/bootstrap/bootstrap-contract.md` | bootstrap boundary | KEEP | текущая реализация |
| `docs/bootstrap/racket.md` | bootstrap backend | KEEP | текущая реализация |
| `docs/bootstrap/host.md` | host surface | KEEP | но явно временный слой |
| `docs/bootstrap/c-interop.md` | C bridge | KEEP | переходная практическая необходимость |
| `docs/bootstrap/sys.md` | sys bridge | REVIEW | проверить, нужен ли в v0.1 |
| `docs/bootstrap/README.md` | bootstrap index | KEEP | навигация |
| `docs/hardware/*` | будущая машина | ARCHIVE | не смешивать с текущим языком |
| `docs/visual/*.html` | визуальные эксперименты | ARCHIVE | не часть toolchain |
| `docs/visual/README.md` | visual index | ARCHIVE | вместе с visual experiments |

## Примеры

| Path | Role | Action | Reason |
|---|---|---|---|
| `examples/canonical/` | официальные примеры | KEEP | один канонический пользовательский путь |
| `examples/user/` | пользовательские примеры | KEEP | практическая проверка |
| `examples/showcase/` | демонстрация синтаксиса | MERGE | слить с canonical или user |
| `examples/bootstrap/` | лаборатория backend/VM | ARCHIVE | не показывать как обычный S-код |
| `examples/apps/family-ledger/` | app prototype | REVIEW | оставить только если это главный demo |

## Tasks

| Path | Role | Action | Reason |
|---|---|---|---|
| `tasks/` | runnable learning suite | KEEP | тестирует путь пользователя |
| `docs/start/task-lessons.md` | текстовый дубль tasks | MERGE | источник должен быть один |

## S-side tree

| Path | Role | Action | Reason |
|---|---|---|---|
| `s/make/` | будущий compiler/toolchain | REVIEW | пока vision, не active implementation |
| `s/run/` | будущий runtime/core | REVIEW | отделить working от planned |
| `s/machine/` | будущая machine/OS | ARCHIVE | слишком ранний слой для v0.1 |

## Первые безопасные действия

1. Удалить generated `tools/compiled/` из Git и добавить ignore.
2. Перенести `docs/visual/` и `docs/hardware/` в archive.
3. Удалить `docs/start/today.md` после переноса только актуальных пунктов.
4. Объединить `start/layers.md` с `architecture/layers.md`.
5. Не объединять `vm-step-v0.md` и `s-machine-v0.md`: первый описывает перенос инструкций в S, второй — модель наблюдаемого исполнения.
6. Разделить активные документы и vision-документы.

Удалять реализацию, parser fixtures и действующие тесты можно только после отдельной проверки зависимостей.

## Аудит канонического синтаксиса

Проверка сделана по четырём слоям: grammar, parser/checker/runtime и реальные
примеры. Канон не расширяем; всё, что не имеет рабочего пути через все слои,
считается черновиком или историческим хвостом.

| Конструкция | Статус | Решение |
|---|---|---|
| `program(...) {}` | canonical | единственная точка входа |
| `skill name(...) {}` | canonical | единственная форма вызываемого поведения |
| `@name = value` | canonical | единственное объявление локального значения |
| `name = value` | canonical | единственное повторное присваивание |
| `out value` | canonical | единственный возврат из `skill` |
| `(condition) {}` | canonical | единственная форма условного блока |
| `(value) { .TAG => value }` | canonical | единственная форма выбора по enum |
| `drum (count) {}` | canonical | единственный цикл v0.1 |
| `value rescue |error| {}` | canonical | единственная форма локальной обработки ошибки |
| `Box` | canonical | единственная форма структурированного значения |
| `Group` | canonical v0 | единственная высокоуровневая коллекция |
| `enum` | canonical v0 | закрытый набор вариантов |
| `use core` | canonical v0 | единственный пользовательский импорт |
| `host.*` | bootstrap-only | не использовать в canonical/user примерах |
| `try` | remove from active canon | точный синтаксис не существует; не рекламировать |
| `union` | remove from active v0 docs | не реализован и содержит чужую Zig-подобную нотацию |
| typed declarations | remove from active v0 docs | не реализованы |
| system arrays/slices/pointers | vision only | оставить только в bootstrap/vision документах |
| `for`, `while`, `foreach` | rejected | второй путь к циклам не нужен |

### Вывод

Рабочее ядро синтаксиса уже соответствует правилу одного пути. Главная
проблема — документы иногда показывают будущие или переходные идеи рядом с
каноном. Следующий шаг — пометить такие документы как vision/bootstrap либо
убрать из активной спецификации, не трогая тесты и реализацию без отдельного
решения.

## Результат проверки дублей

`vm-step-v0.md` и `s-machine-v0.md` похожи по теме, но не дублируют друг друга:

- `s-machine-v0` отвечает, что такое наблюдаемое исполнение S;
- `vm-step-v0` отвечает, как конкретные инструкции переносятся из Racket VM в
  будущий S-код.

`modules.md` задаёт политику импорта, а `object-module-v0.md` описывает
конкретный локальный импорт объектов. Их объединение уничтожило бы границу
между правилом и реализацией.

`object-skill-call-v0.md` оставлен на review: это не дубль импорта, но его
связь с текущими `Box`, `world` и `skill` ещё недостаточно короткая для
активного v0-канона.

## Выполнено: очистка типов

`docs/current/types.md` теперь описывает только работающие формы `none`, `yes/no`,
`Box`, `Group` и `enum`. Незавершённые `union`, typed declarations, arrays,
slices и pointers вынесены из активного v0-текста. Они не удалены из истории
проекта — просто больше не выглядят как доступные конструкции языка.
