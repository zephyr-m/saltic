default:
    just --list

parse file="examples/basic.s":
    racket tools/parse.rkt {{file}}

test:
    raco test tests

docs:
    @echo "docs are in README.md and docs/"

vscode-package:
    racket tools/package-vscode.rkt

vscode-install: vscode-package
    code --install-extension dist/s-language-0.1.4.vsix --force

example:
    @echo "examples/basic.s"
    @just parse examples/basic.s

explain file="examples/basic.s":
    @echo "explain is not implemented yet"
    @echo "next step: build a small AST explainer for {{file}}"

check:
    racket tools/check.rkt examples/basic.s

format:
    racket tools/format.rkt examples/basic.s

format-file file="examples/basic.s":
    racket tools/format.rkt {{file}}

run:
    racket tools/run.rkt examples/basic.s

run-file file="examples/basic.s" *args:
    racket tools/run.rkt {{file}} {{args}}
