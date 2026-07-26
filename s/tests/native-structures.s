use s.make.compiler.compiler
use s.make.tester

skill expect_llvm(state, source, needle, path) {
    @compiled = compiler_compile(source, path)
    state = tester_expect_in(state, core.group.count(compiled.diagnostics), 0)
    state = tester_expect_in(state, core.str.contains(compiled.llvm, needle), yes)
    out state
}

program() {
    @state = tester_start()
    state = expect_llvm(state, "skill message() { out \"hello\" } program() { @text = message() out core.io.show(text) }", "define ptr @message()", "native-skill.s")
    state = expect_llvm(state, "skill greet(name) { out core.io.show(name) } program() { out greet(\"Candy\") }", "define i32 @greet(ptr %name)", "native-skill-arg.s")
    state = expect_llvm(state, "skill repeat(count) { drum (count) { out core.io.show(\"tick\") } out 0 } program() { out repeat(3) }", "%drum_index = phi i32", "native-drum.s")
    state = expect_llvm(state, "skill count(limit) { @value = 0 drum (limit) { value = value + 1 } out value } program() { out count(5) }", "%value = phi i32", "native-drum-number.s")
    state = expect_llvm(state, "program() { @items = [4, 7, 9] out core.group.count(items) }", "%Group = type { i32, [16 x i32] }", "native-group.s")
    state = expect_llvm(state, "program() { @items = [4, 7, 9] out core.group.item(items, 1) }", " = load i32, ptr %group_item_ptr_", "native-group-item.s")
    state = expect_llvm(state, "program() { @items = [4, 7] @next = core.group.add(items, 9) out core.group.item(next, 2) }", "call void @group_add(ptr %items, i32 9, ptr %next)", "native-group-add.s")
    state = expect_llvm(state, "Point = Box { x = 0, y = 0 } program() { @point = Point { x = 7, y = 5 } out point.x }", "%Box_Point = type { i32, i32 }", "native-box.s")
    state = expect_llvm(state, "Point = Box { x = 1, y = 5 } program() { @point = Point { x = 7 } out point.y }", "store i32 5, ptr %point_field_1", "native-box-default.s")
    state = expect_llvm(state, "Point = Box { x = 0 } program() { @point = Point {} point.x = 9 out point.x }", "store i32 9, ptr %box_set_ptr_", "native-box-set.s")
    state = expect_llvm(state, "Point = Box { x = 0, y = 0 } skill make_point(x, y) { out Point { x = x, y = y } } program() { @point = make_point(7, 5) out point.x }", "define void @make_point(i32 %x, i32 %y, ptr %result)", "native-box-skill.s")
    state = expect_llvm(state, "Point = Box { x = 0 } skill move(point, x) { point.x = x out point } program() { @point = Point {} @next = move(point, 9) out next.x }", "define ptr @move(ptr %point, i32 %x)", "native-box-change.s")
    state = expect_llvm(state, "Point = Box { x = 0, y = 0 } skill move(point, x, y) { point.x = x point.y = y out point } program() { @point = Point {} @next = move(point, 7, 9) out next.y }", "%field_ptr_1 = getelementptr %Box_Point", "native-box-change-many.s")
    state = expect_llvm(state, "Point = Box { x = 0, y = 0 } skill move(point, x, y) { point.x = x point.y = y out point } skill shift(point, x) { point.x = x out point } program() { @point = Point {} @moved = move(point, 7, 9) @shifted = shift(moved, 12) out shifted.x }", "%shifted = call ptr @shift(ptr %moved, i32 12)", "native-box-chain.s")
    tester_summary_state(state)
    out none
}
