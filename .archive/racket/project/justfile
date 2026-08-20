default:
    just --list

parse file="examples/bootstrap/basic.s":
    racket racket/bootstrap/1-parser.rkt {{file}}

test:
    raco test tests

native-test:
    racket racket/bootstrap/4-vm.rkt s/tests/native-numbers.s
    racket racket/bootstrap/4-vm.rkt s/tests/native-structures.s
    racket racket/bootstrap/4-vm.rkt s/tests/native-strings.s
    nix-shell -p llvmPackages.clang --run 'bash s/tests/native.sh'

verify:
    just canonical
    just user-examples
    env TMPDIR=/tmp raco test tests/checker.rkt tests/modules.rkt tests/parser.rkt tests/vm.rkt

canonical:
    env TMPDIR=/tmp raco test tests/canonical.rkt
    racket racket/bootstrap/2-checker.rkt examples/canonical/text-auditor.core.s
    racket racket/bootstrap/2-checker.rkt examples/canonical/report-generator.core.s
    racket racket/bootstrap/4-vm.rkt examples/canonical/text-auditor.core.s docs/start/roadmap.md roadmap
    racket racket/bootstrap/4-vm.rkt examples/canonical/report-generator.core.s examples/canonical/report-target.txt runtime

user-examples:
    env TMPDIR=/tmp raco test tests/user-examples.rkt
    racket racket/bootstrap/2-checker.rkt examples/user/count-lines.s
    racket racket/bootstrap/2-checker.rkt examples/user/finance-log.s
    racket racket/bootstrap/4-vm.rkt examples/user/count-lines.s docs/start/roadmap.md
    racket racket/bootstrap/4-vm.rkt examples/user/finance-log.s

family-ledger:
    racket racket/bootstrap/4-vm.rkt examples/apps/family-ledger/main.s examples/apps/family-ledger/ledger.txt

family-ledger-ui:
    racket racket/bootstrap/4-vm.rkt examples/apps/family-ledger/ui.s examples/apps/family-ledger/ledger.txt

docs:
    @echo "docs are in README.md and docs/"

example:
    @echo "examples/bootstrap/basic.s"
    @just parse examples/bootstrap/basic.s

check:
    racket racket/bootstrap/2-checker.rkt examples/bootstrap/basic.s

check-file file="examples/bootstrap/basic.s":
    racket racket/bootstrap/2-checker.rkt {{file}}

vm-run file="examples/bootstrap/vm-basic.s":
    racket racket/bootstrap/4-vm.rkt {{file}}

vm-bytecode file="examples/bootstrap/vm-basic.s":
    racket racket/bootstrap/4-vm.rkt --bytecode {{file}}

vm-box:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/vm-box.s

vm-box-bytecode:
    racket racket/bootstrap/4-vm.rkt --bytecode examples/bootstrap/vm-box.s

vm-group:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/vm-group.s

vm-group-bytecode:
    racket racket/bootstrap/4-vm.rkt --bytecode examples/bootstrap/vm-group.s

vm-rescue:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/vm-rescue.s

vm-rescue-bytecode:
    racket racket/bootstrap/4-vm.rkt --bytecode examples/bootstrap/vm-rescue.s

vm-control:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/vm-control.s

vm-control-bytecode:
    racket racket/bootstrap/4-vm.rkt --bytecode examples/bootstrap/vm-control.s

vm-visual:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/vm-visual.s

vm-visual-bytecode:
    racket racket/bootstrap/4-vm.rkt --bytecode examples/bootstrap/vm-visual.s

vm-world:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/vm-world-emit.s

vm-world-bytecode:
    racket racket/bootstrap/4-vm.rkt --bytecode examples/bootstrap/vm-world-emit.s

object-skill-calls:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/object-skill-calls.s

object-skill-calls-vm:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/object-skill-calls.s

s-vm-tiny:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/s-vm-tiny.s

s-vm-tiny-vm:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/s-vm-tiny.s

s-vm-tiny-traced:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/s-vm-tiny-traced.s

s-vm-tiny-traced-vm:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/s-vm-tiny-traced.s

s-vm-step-ab:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/s-vm-step-ab.s

s-vm-step-ab-vm:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/s-vm-step-ab.s

s-vm-step-c:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/s-vm-step-c.s

s-vm-step-c-vm:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/s-vm-step-c.s

s-vm-step-d:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/s-vm-step-d.s

s-vm-step-d-vm:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/s-vm-step-d.s

s-vm-step-drum:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/s-vm-step-drum.s

s-vm-step-drum-vm:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/s-vm-step-drum.s

s-vm-step-switch:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/s-vm-step-switch.s

s-vm-step-switch-vm:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/s-vm-step-switch.s

s-vm-step-rescue:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/s-vm-step-rescue.s

s-vm-step-rescue-vm:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/s-vm-step-rescue.s

s-vm-step-call:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/s-vm-step-call.s

s-vm-step-call-vm:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/s-vm-step-call.s

s-vm-step-boundary:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/s-vm-step-boundary.s

s-vm-step-boundary-vm:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/s-vm-step-boundary.s

run:
    racket racket/bootstrap/4-vm.rkt examples/bootstrap/basic.s

run-file file="examples/bootstrap/basic.s" *args:
    racket racket/bootstrap/4-vm.rkt {{file}} {{args}}
