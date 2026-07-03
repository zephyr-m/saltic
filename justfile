default:
    just --list

parse file="examples/bootstrap/basic.s":
    racket tools/parse.rkt {{file}}

test:
    raco test tests

verify:
    just canonical
    just user-examples
    just task tasks/001-finance-balance
    just task tasks/002-energy-day
    just task tasks/003-energy-week
    just task tasks/004-render-frame
    just task tasks/005-render-scene-group
    just task tasks/006-object-module
    just task tasks/007-object-reaction-chain
    just task tasks/008-object-interaction
    just task tasks/009-laboratory-sandbox-loop
    just task tasks/010-laboratory-history
    just task tasks/011-visual-observation-protocol
    just task tasks/012-actor-fabric-pulse
    just effects-check
    env TMPDIR=/tmp raco test tests/checker.rkt tests/effects.rkt tests/effects-check.rkt tests/explainer.rkt tests/formatter.rkt tests/machine-trace.rkt tests/modules.rkt tests/parser.rkt tests/runtime.rkt tests/task.rkt

canonical:
    env TMPDIR=/tmp raco test tests/canonical.rkt
    racket tools/check.rkt examples/canonical/text-auditor.core.s
    racket tools/check.rkt examples/canonical/report-generator.core.s
    racket tools/run.rkt examples/canonical/text-auditor.core.s docs/start/roadmap.md roadmap
    racket tools/run.rkt examples/canonical/report-generator.core.s examples/canonical/report-target.txt runtime

user-examples:
    env TMPDIR=/tmp raco test tests/user-examples.rkt
    racket tools/check.rkt examples/user/count-lines.s
    racket tools/check.rkt examples/user/finance-log.s
    racket tools/run.rkt examples/user/count-lines.s docs/start/roadmap.md
    racket tools/run.rkt examples/user/finance-log.s

family-ledger:
    racket tools/run.rkt examples/apps/family-ledger/main.s examples/apps/family-ledger/ledger.txt

family-ledger-ui:
    racket tools/run.rkt examples/apps/family-ledger/ui.s examples/apps/family-ledger/ledger.txt

family-ledger-frame:
    racket tools/ui-framebuffer.rkt --png /tmp/family-ledger-ui.png examples/apps/family-ledger/ui.s examples/apps/family-ledger/ledger.txt

family-ledger-window:
    racket tools/family-ledger-gui.rkt

family-ledger-world:
    racket tools/family-ledger-world.rkt

task dir="tasks/001-finance-balance":
    racket tools/task.rkt {{dir}}

docs:
    @echo "docs are in README.md and docs/"

vscode-package:
    racket tools/package-vscode.rkt

vscode-install: vscode-package
    code --install-extension dist/s-language-0.1.4.vsix --force

example:
    @echo "examples/bootstrap/basic.s"
    @just parse examples/bootstrap/basic.s

explain file="examples/bootstrap/basic.s":
    racket tools/explain.rkt {{file}}

check:
    racket tools/check.rkt examples/bootstrap/basic.s

check-file file="examples/bootstrap/basic.s":
    racket tools/check.rkt {{file}}

format:
    racket tools/format.rkt examples/bootstrap/basic.s

format-file file="examples/bootstrap/basic.s":
    racket tools/format.rkt {{file}}

machine-trace file="tasks/011-visual-observation-protocol/solution.s":
    racket tools/machine-trace.rkt {{file}}

vm-run file="examples/bootstrap/vm-basic.s":
    racket tools/vm-run.rkt {{file}}

vm-bytecode file="examples/bootstrap/vm-basic.s":
    racket tools/vm-run.rkt --bytecode {{file}}

vm-box:
    racket tools/vm-run.rkt examples/bootstrap/vm-box.s

vm-box-bytecode:
    racket tools/vm-run.rkt --bytecode examples/bootstrap/vm-box.s

vm-group:
    racket tools/vm-run.rkt examples/bootstrap/vm-group.s

vm-group-bytecode:
    racket tools/vm-run.rkt --bytecode examples/bootstrap/vm-group.s

vm-rescue:
    racket tools/vm-run.rkt examples/bootstrap/vm-rescue.s

vm-rescue-bytecode:
    racket tools/vm-run.rkt --bytecode examples/bootstrap/vm-rescue.s

vm-control:
    racket tools/vm-run.rkt examples/bootstrap/vm-control.s

vm-control-bytecode:
    racket tools/vm-run.rkt --bytecode examples/bootstrap/vm-control.s

vm-visual:
    racket tools/vm-run.rkt examples/bootstrap/vm-visual.s

vm-visual-bytecode:
    racket tools/vm-run.rkt --bytecode examples/bootstrap/vm-visual.s

vm-world:
    racket tools/vm-run.rkt examples/bootstrap/vm-world-emit.s

vm-world-bytecode:
    racket tools/vm-run.rkt --bytecode examples/bootstrap/vm-world-emit.s

object-skill-calls:
    racket tools/run.rkt examples/bootstrap/object-skill-calls.s

object-skill-calls-vm:
    racket tools/vm-run.rkt examples/bootstrap/object-skill-calls.s

s-vm-tiny:
    racket tools/run.rkt examples/bootstrap/s-vm-tiny.s

s-vm-tiny-vm:
    racket tools/vm-run.rkt examples/bootstrap/s-vm-tiny.s

s-vm-tiny-traced:
    racket tools/run.rkt examples/bootstrap/s-vm-tiny-traced.s

s-vm-tiny-traced-vm:
    racket tools/vm-run.rkt examples/bootstrap/s-vm-tiny-traced.s

s-vm-step-ab:
    racket tools/run.rkt examples/bootstrap/s-vm-step-ab.s

s-vm-step-ab-vm:
    racket tools/vm-run.rkt examples/bootstrap/s-vm-step-ab.s

s-vm-step-c:
    racket tools/run.rkt examples/bootstrap/s-vm-step-c.s

s-vm-step-c-vm:
    racket tools/vm-run.rkt examples/bootstrap/s-vm-step-c.s

s-vm-step-d:
    racket tools/run.rkt examples/bootstrap/s-vm-step-d.s

s-vm-step-d-vm:
    racket tools/vm-run.rkt examples/bootstrap/s-vm-step-d.s

s-vm-step-drum:
    racket tools/run.rkt examples/bootstrap/s-vm-step-drum.s

s-vm-step-drum-vm:
    racket tools/vm-run.rkt examples/bootstrap/s-vm-step-drum.s

s-vm-step-switch:
    racket tools/run.rkt examples/bootstrap/s-vm-step-switch.s

s-vm-step-switch-vm:
    racket tools/vm-run.rkt examples/bootstrap/s-vm-step-switch.s

s-vm-step-rescue:
    racket tools/run.rkt examples/bootstrap/s-vm-step-rescue.s

s-vm-step-rescue-vm:
    racket tools/vm-run.rkt examples/bootstrap/s-vm-step-rescue.s

s-vm-step-call:
    racket tools/run.rkt examples/bootstrap/s-vm-step-call.s

s-vm-step-call-vm:
    racket tools/vm-run.rkt examples/bootstrap/s-vm-step-call.s

s-vm-step-boundary:
    racket tools/run.rkt examples/bootstrap/s-vm-step-boundary.s

s-vm-step-boundary-vm:
    racket tools/vm-run.rkt examples/bootstrap/s-vm-step-boundary.s

effects:
    racket tools/effects.rkt

effects-check:
    racket tools/effects-check.rkt

run:
    racket tools/run.rkt examples/bootstrap/basic.s

run-file file="examples/bootstrap/basic.s" *args:
    racket tools/run.rkt {{file}} {{args}}
