use core
skill count(limit) { @value = 0 drum (limit) { value = value + 1 } out value }
program() { out count(5) }
