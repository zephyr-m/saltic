карта self-hosting S

назначение
├─ не теряться в проекте
├─ видеть где язык, где runtime, где bootstrap, где цель
├─ держать следующий шаг маленьким и проверяемым
└─ не лезть в большие темы без runnable evidence

правила чтения
├─ атом = файл или директория
├─ [ ] сделать
├─ [~] в работе
├─ [x] есть/прочитано/подтверждено
├─ [!] риск/блокер
└─ [?] нужно решение

главная карта
├─ [x] README.md
│  └─ S = системный язык + digital paper + Racket bootstrap + автономность около 40%
├─ [x] Structure.md
│  └─ freeze целевой структуры: s/runtime, s/vm, s/compiler, s/effects, s/tooling, s/host
├─ [x] docs/README.md
│  └─ вход в документацию; читать сначала vision/start/spec/bootstrap/tooling/hardware
├─ [x] docs/vision/digital-paper.md
│  └─ смысл: paper -> check -> explain -> run -> observe -> modify -> persist
├─ [x] docs/vision/world.md
│  └─ цель: world -> act -> observe -> modify -> simulate -> persist
├─ [x] docs/vision/programmable-matter.md
│  └─ дальний север: actor matter; не закрывать путь к physical action
├─ [x] docs/architecture/layers.md
│  └─ слои: L1 runtime, L2 std, L3 core, L4 packages, bootstrap host, toolchain, target machine
├─ [x] docs/start/roadmap.md
│  └─ общий путь: parse -> check -> run -> bytecode VM -> tiny VM -> self-hosting
├─ [x] docs/start/today.md
│  └─ текущий next: расширить S-side BoundaryTable
├─ [x] docs/start/self-hosting-roadmap.md
│  └─ путь: S source -> S compiler -> S bytecode -> S VM -> S std/tools
├─ [x] docs/start/autonomy-score.md
│  └─ текущая оценка: S 40%, Racket 60%, self-hosting chain 5%
├─ [x] docs/start/runtime-freeze.md
│  └─ runtime растёт только через contract + task/example + test + trace/effect explanation
└─ [x] docs/start/task-lessons.md
   └─ новые фичи идут из runnable tasks, не из желания дорисовать язык

текущий снимок
├─ [x] .s файлы реально запускаются
│  └─ evidence: just run-file, just task, examples/user, examples/canonical
├─ [x] parser/checker/runtime есть
│  └─ owner сейчас: tools/*.rkt
├─ [x] bytecode VM есть
│  └─ owner сейчас: tools/s-vm.rkt + tools/vm-run.rkt
├─ [x] bytecode contract есть
│  └─ docs/spec/bytecode-v0.md
├─ [x] S Machine contract есть
│  └─ docs/spec/s-machine-v0.md
├─ [x] VM Step transfer map есть
│  └─ docs/spec/vm-step-v0.md
├─ [x] tiny VM на S есть
│  └─ examples/bootstrap/tiny_vm/core.s
├─ [x] часть std на S есть
│  └─ std/file.s std/json.s std/num.s std/str.s
├─ [x] world/visual protocol slices есть
│  └─ world.emit/world.step + visual trace
└─ [!] full self-hosting ещё далеко
   └─ parser/checker/compiler/full runtime/tooling всё ещё в Racket

дистанция до self-hosting
├─ [x] уровень 0: docs + examples
├─ [x] уровень 10: parser/checker/runtime существуют
├─ [x] уровень 25: полезные маленькие S-программы запускаются
├─ [~] уровень 40: S std modules + bytecode contract + S-side VM subset
├─ [ ] уровень 60: большая часть VM/std semantics живёт в S
├─ [ ] уровень 80: parser/checker/compiler/tooling частично на S
└─ [ ] уровень 100: S поддерживает и собирает основной toolchain

текущая рабочая линия
├─ [x] examples/bootstrap/tiny_vm/core.s
│  └─ есть Op, Instr, Frame, Stack, Env, TinyProgram, BoundaryTable
├─ [x] examples/bootstrap/s-vm-step-boundary.s
│  └─ runnable пример: local call + core.io.println + core.group.count/at
├─ [x] tests/runtime.rkt
│  └─ проверяет пример через tree runtime
├─ [x] tests/vm.rkt
│  └─ проверяет пример через bytecode VM
├─ [~] docs/spec/vm-step-v0.md
│  └─ нужно держать синхронно с tiny VM transfer
├─ [~] docs/start/self-hosting-roadmap.md
│  └─ нужно фиксировать каждый перенос смысла из Racket в S
└─ [ ] следующий атом
   └─ world.trace_text или visual.trace_text в S-side BoundaryTable

что значит "перенос смысла"
├─ плохо
│  └─ core API -> renamed Racket wrapper -> тот же смысл в tools/s-runtime.rkt
├─ нормально
│  └─ core API -> S module/VM model -> минимальный host primitive
└─ self-hosting progress
   └─ поведение можно понять из .s файла, а Racket остаётся reference/backend

главные блокеры
├─ [!] tools/s-parser.rkt
│  └─ parser полностью Racket
├─ [!] tools/s-checker.rkt
│  └─ checker полностью Racket
├─ [!] tools/s-runtime.rkt
│  └─ tree runtime + host/core/world/visual dispatch
├─ [!] tools/s-vm.rkt
│  └─ full bytecode VM semantics всё ещё Racket
├─ [!] module loader
│  └─ локальные object modules есть, но loader/toolchain не self-hosted
├─ [!] diagnostics/tooling
│  └─ explain/format/check/task/effects orchestration в Racket
├─ [!] tests orchestration
│  └─ raco/just держат проверку, S test runner ещё нет
└─ [!] bytecode as data
   └─ tiny VM пока использует S-side Instr boxes, не полный bytecode dump как вход

не блокеры прямо сейчас
├─ [x] "нет data structures"
│  └─ неверно: Box/Group есть; проблема в мощности и dynamic representation
├─ [x] "нет file/text primitives"
│  └─ неверно: core.file/core.str есть частично; проблема в зрелости для compiler/toolchain
├─ [x] "нет world"
│  └─ неверно: world action/trace MVP есть; это не физика, но рабочий slice
└─ [x] "надо сразу переписать parser"
   └─ неверно: docs явно говорят не начинать с full parser rewrite

полный аудит / маршрут
├─ [~] карта репозитория
│  ├─ [ ] README.md
│  ├─ [x] Structure.md
│  ├─ [ ] docs/
│  ├─ [x] s/
│  ├─ [ ] tools/
│  ├─ [ ] std/
│  ├─ [ ] examples/
│  ├─ [ ] tasks/
│  ├─ [ ] tests/
│  ├─ [ ] editors/
│  ├─ [ ] justfile
│  └─ [ ] build/ generated artifacts
├─ [ ] цепочка исполнения
│  ├─ [ ] parse: tools/parse.rkt + tools/s-parser.rkt
│  ├─ [ ] check: tools/check.rkt + tools/s-checker.rkt
│  ├─ [ ] run tree-runtime: tools/run.rkt + tools/s-runtime.rkt
│  ├─ [ ] compile bytecode: tools/s-vm.rkt
│  ├─ [ ] run bytecode VM: tools/vm-run.rkt + tools/s-vm.rkt
│  └─ [ ] run S-side tiny VM: examples/bootstrap/tiny_vm/core.s
├─ [ ] semantic ownership
│  ├─ [ ] syntax ownership
│  ├─ [ ] type/check ownership
│  ├─ [ ] std ownership
│  ├─ [ ] VM step ownership
│  ├─ [ ] boundary ownership
│  └─ [ ] world/visual protocol ownership
├─ [ ] evidence files
│  ├─ [ ] tests/parser.rkt
│  ├─ [ ] tests/checker.rkt
│  ├─ [ ] tests/runtime.rkt
│  ├─ [ ] tests/vm.rkt
│  ├─ [ ] tests/modules.rkt
│  ├─ [ ] tests/effects.rkt
│  ├─ [ ] tests/effects-check.rkt
│  └─ [ ] tests/task.rkt
└─ [ ] audit output
   ├─ [ ] обновить autonomy score
   ├─ [ ] ranked blocker list
   ├─ [ ] следующие 3 file-level actions
   └─ [ ] verification command set

verification baseline
├─ [x] just s-vm-step-boundary
│  └─ pass на поверхностном аудите
├─ [x] just s-vm-step-boundary-vm
│  └─ pass на поверхностном аудите
├─ [ ] env TMPDIR=/tmp raco test tests/runtime.rkt tests/vm.rkt
│  └─ минимум после изменения текущей boundary линии
└─ [ ] just verify
   └─ полный локальный контракт

запреты для ясности
├─ [!] не добавлять runtime intrinsic без docs/task/test/effects
├─ [!] не считать host.* пользовательским API
├─ [!] не превращать Box в class/object
├─ [!] не добавлять новый цикл вместо drum без задач
├─ [!] не делать visual HTML/canvas API
├─ [!] не делать world обычным GUI/app
├─ [!] не начинать full parser rewrite
├─ [!] не строить actor fabric в runtime до contract/task/test
└─ [!] не путать self-hosting с "больше .s файлов"

следующие 3 file-level actions
├─ [1] examples/bootstrap/tiny_vm/core.s
│  └─ выровнять фактический BoundaryTable с docs/start/today.md
├─ [2] examples/bootstrap/s-vm-step-boundary.s
│  └─ закрыть string boundary пример или выбрать следующий handler
└─ [3] s/runtime/* + s/vm/* + Structure.md
   └─ переносить tools/s-runtime.rkt и tiny_vm/core.s в заранее выделенные S slots

текущий вывод
├─ S не близко к полному self-hosting
├─ S уже вышел за пределы toy parser/checker/runtime
├─ ближайшая ценность: первая честная execution self-hosting loop
├─ Stage 4 target: Racket VM runs S VM, S VM runs S bytecode as data
└─ ближайший маленький шаг: ещё один protocol boundary handler в tiny VM
