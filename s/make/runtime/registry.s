use core

RuntimeRegistry = Box {
    skills = []
    builtins = []
}

RuntimeLookup = Box {
    found = no
    value = none
    builtin = ""
}

skill runtime_registry_start() {
    out RuntimeRegistry {
        skills = []
        builtins = ["core.num.add", "core.num.sub", "core.num.mul", "core.num.div", "core.num.text"]
    }
}

skill runtime_registry_add(registry, decl) {
    out RuntimeRegistry {
        skills = core.group.add(registry.skills, decl)
    }
}

skill runtime_registry_find(registry, name) {
    @index = 0
    @found = no
    @value = none
    @builtin = ""
    @count = core.group.count(registry.skills)
    drum (count) {
        (index < count) {
            @decl = core.group.item(registry.skills, index)
            (decl.name == name) {
                found = yes
                value = decl
            }
            index = index + 1
        }
    }
    @builtin_index = 0
    @builtin_count = core.group.count(registry.builtins)
    drum (builtin_count) {
        (builtin_index < builtin_count) {
            @builtin_name = core.group.item(registry.builtins, builtin_index)
            (builtin_name == name) {
                found = yes
                builtin = builtin_name
            }
            builtin_index = builtin_index + 1
        }
    }
    out RuntimeLookup {
        found = found
        value = value
        builtin = builtin
    }
}
