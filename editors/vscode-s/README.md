# S Language VS Code Extension

This extension adds early editor support for S:

- `.saltic` language registration;
- TextMate syntax highlighting;
- bracket auto-closing;
- language and file icons.

## Run Locally

Open this directory in VS Code:

```bash
code editors/vscode-s
```

Then press `F5` and open `examples/qemu-hello.saltic` from the Extension Development Host window.

## Current Scope

Highlighting tracks the current `v0.1` language draft:

- `skill`, `out`, `drum`, `stop`, `rescue`, `try`, `use`;
- `enum`, `union`, `Box`;
- constants, variables, enum values;
- strings, numbers, paths, operators;
- draft `@note { ... }` blocks.
