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
    env TMPDIR=/tmp raco test tests/checker.rkt tests/explainer.rkt tests/formatter.rkt tests/parser.rkt tests/runtime.rkt tests/task.rkt

canonical:
    env TMPDIR=/tmp raco test tests/canonical.rkt
    racket tools/check.rkt examples/canonical/text-auditor.std.s
    racket tools/check.rkt examples/canonical/report-generator.std.s
    racket tools/run.rkt examples/canonical/text-auditor.std.s docs/start/roadmap.md roadmap
    racket tools/run.rkt examples/canonical/report-generator.std.s examples/canonical/report-target.txt runtime

user-examples:
    env TMPDIR=/tmp raco test tests/user-examples.rkt
    racket tools/check.rkt examples/user/count-lines.s
    racket tools/check.rkt examples/user/finance-log.s
    racket tools/run.rkt examples/user/count-lines.s docs/start/roadmap.md
    racket tools/run.rkt examples/user/finance-log.s

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

run:
    racket tools/run.rkt examples/bootstrap/basic.s

run-file file="examples/bootstrap/basic.s" *args:
    racket tools/run.rkt {{file}} {{args}}
