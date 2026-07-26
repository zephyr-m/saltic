use core
skill repeat(count) { drum (count) { out core.io.show("tick") } out 0 }
program() { out repeat(3) }
