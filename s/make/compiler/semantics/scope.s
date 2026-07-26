use core

Scope = Box {
    names = []
    values = []
    parent = none
}

ScopeLookup = Box {
    found = no
    value = none
}

skill scope_start() {
    out Scope {}
}

skill scope_child(parent) {
    out Scope {
        names = []
        values = []
        parent = parent
    }
}

skill scope_put(scope, name, value) {
    @index = 0
    @found = no
    @names = scope.names
    @values = scope.values
    @count = core.group.count(names)
    drum (count) {
        (index < count) {
            @known = core.group.item(names, index)
            (known == name) {
                values = core_group_replace(values, index, value)
                found = yes
            }
            index = index + 1
        }
    }
    (found == yes) {
        out Scope {
            names = names
            values = values
        }
    }
    out Scope {
        names = core.group.add(names, name)
        values = core.group.add(values, value)
    }
}

skill scope_get(scope, name) {
    @index = 0
    @found = no
    @value = none
    @has_parent = yes
    @count = core.group.count(scope.names)
    drum (count) {
        (index < count) {
            @known = core.group.item(scope.names, index)
            (known == name) {
                found = yes
                value = core.group.item(scope.values, index)
            }
            index = index + 1
        }
    }
    (found == no) {
        (scope.parent == none) {
            has_parent = no
        }
        (has_parent == yes) {
            @outer = scope_get(scope.parent, name)
            (outer.found == yes) {
                found = yes
                value = outer.value
            }
        }
    }
    out ScopeLookup {
        found = found
        value = value
    }
}

skill scope_has(scope, name) {
    @lookup = scope_get(scope, name)
    out lookup.found
}
