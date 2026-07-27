use core
skill message() { out "hello from skill" }
program() { @text = message() out core.io.show(text) }
