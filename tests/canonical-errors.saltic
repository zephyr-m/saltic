Number = 1
Number = 2
Answer = yes
UnknownConstant = MissingName

Shade = enum {
    LIGHT,
    DARK,
}

Point = Box {
    x = 0
    label = "point"
}

BrokenFields = Box {
    value = 0
    value = 1
}

BrokenSkills = Box {
    value = 0

    skill duplicate(item, item) {
        out none
    }

    skill duplicate() {
        out none
    }
}

skill duplicate_parameters(item, item) {
    out none
}

skill invalid_operations() {
    @number = 1
    number = "text"
    @number = 2
    @Answer = no

    @group = [1]
    group = ["text"]

    Number = 3
    Point = Point {}
    missing = 1

    @conflict = MissingName
    @unknown_call = missing_skill()
    @unknown_box = MissingBox {}
    @unknown_enum = Shade.INVISIBLE

    @point = Point {}
    @missing_field = point.missing
    point.missing = 1
    point.x = "text"

    @text = "text"
    @text_field = text.missing

    @wrong_field_type = Point { x = "text" }
    @extra_field = Point { missing = 1 }
    @duplicate_field = Point { x = 1 x = 2 }

    @bad_add = "text" + 1
    @bad_compare = yes > 1
    @core_without_import = core.group.count([])

    out none
}

program() {
    invalid_operations()
    out none
}

program() {
    out none
}
