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
    @echo "checker is not implemented yet"

format:
    @echo "formatter is not implemented yet"

run:
    @echo "interpreter is not implemented yet"
