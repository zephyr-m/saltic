# S Language VS Code Extension

This extension adds early editor support for S:

- `.s` language registration;
- TextMate syntax highlighting;
- bracket auto-closing;
- language and file icons.

## Run Locally

Open this directory in VS Code:

```bash
code editors/vscode-s
```

Then press `F5` and open `examples/basic.s` from the Extension Development Host window.

## Install Locally

From the repository root:

```bash
just vscode-package
just vscode-install
```

After installation, `.s` files open with S highlighting in the normal VS Code window.

To show the S file icon, select the icon theme once:

```text
Developer: Reload Window
Preferences: File Icon Theme -> S Language Icons
```

The repository workspace also pins:

```json
{
  "files.associations": {
    "*.s": "s"
  },
  "workbench.iconTheme": "s-language-icons"
}
```

This avoids the common `.s` collision with assembly file icons.

## Current Scope

Highlighting tracks the current `v0.1` language draft:

- `skill`, `out`, `drum`, `stop`, `rescue`, `try`, `use`;
- `enum`, `union`, `Box`;
- constants, variables, enum values;
- strings, numbers, paths, operators;
- draft `@note { ... }` blocks.
