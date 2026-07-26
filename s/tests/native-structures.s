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
    state = expect_llvm(state, "program() { @items = [4, 7, 9] out core.group.count(items) }", "%Group = type { i32, [16 x %Value] }", "native-group.s")
    state = expect_llvm(state, "program() { @items = [4, 7, 9] out core.group.item(items, 1) }", " = load i64, ptr %group_item_data_ptr_", "native-group-item.s")
    state = expect_llvm(state, "program() { @items = [4, 7] @next = core.group.add(items, 9) out core.group.item(next, 2) }", "call void @group_add(ptr %items, i32 1, i32 0, i64 9, ptr %next)", "native-group-add.s")
    state = expect_llvm(state, "Point = Box { x = 0, y = 0 } program() { @point = Point { x = 7, y = 5 } out point.x }", "%Box_Point = type { i32, i32 }", "native-box.s")
    state = expect_llvm(state, "Point = Box { x = 1, y = 5 } program() { @point = Point { x = 7 } out point.y }", "store i32 5, ptr %point_field_1", "native-box-default.s")
    state = expect_llvm(state, "Point = Box { x = 0 } program() { @point = Point {} point.x = 9 out point.x }", "store i32 9, ptr %box_set_ptr_", "native-box-set.s")
    state = expect_llvm(state, "Point = Box { x = 0, y = 0 } skill make_point(x, y) { out Point { x = x, y = y } } program() { @point = make_point(7, 5) out point.x }", "define void @make_point(i32 %x, i32 %y, ptr %result)", "native-box-skill.s")
    state = expect_llvm(state, "Point = Box { x = 0 } skill move(point, x) { point.x = x out point } program() { @point = Point {} @next = move(point, 9) out next.x }", "define ptr @move(ptr %point, i32 %x)", "native-box-change.s")
    state = expect_llvm(state, "Point = Box { x = 0, y = 0 } skill move(point, x, y) { point.x = x point.y = y out point } program() { @point = Point {} @next = move(point, 7, 9) out next.y }", "%field_ptr_1 = getelementptr %Box_Point", "native-box-change-many.s")
    state = expect_llvm(state, "Point = Box { x = 0, y = 0 } skill move(point, x, y) { point.x = x point.y = y out point } skill shift(point, x) { point.x = x out point } program() { @point = Point {} @moved = move(point, 7, 9) @shifted = shift(moved, 12) out shifted.x }", "%shifted = call ptr @shift(ptr %moved, i32 12)", "native-box-chain.s")
    state = expect_llvm(state, "Token = Box { kind = \"\", line = 0 } program() { @token = Token { kind = \"NAME\", line = 7 } out core.io.show(token.kind) }", "%Box_Token = type { ptr, i32 }", "native-box-string.s")
    state = expect_llvm(state, "Token = Box { kind = \"\", line = 0 } program() { @token = Token { kind = \"NAME\", line = 7 } token.kind = \"WORD\" out core.io.show(token.kind) }", "store ptr %box_set_string_", "native-box-string-set.s")
    state = expect_llvm(state, "Token = Box { kind = \"\", line = 0 } skill keep(token) { out token } program() { @token = Token { kind = \"NAME\", line = 7 } @same = keep(token) out core.io.show(same.kind) }", "%same = call ptr @keep(ptr %token)", "native-box-string-pass.s")
    state = expect_llvm(state, "Token = Box { kind = \"\", value = \"\", line = 0, col = 0 } skill rename(token, kind) { token.kind = kind out token } program() { @token = Token { kind = \"NAME\", value = \"candy\", line = 7, col = 3 } @renamed = rename(token, \"WORD\") out core.io.show(renamed.kind) }", "define ptr @rename(ptr %token, ptr %kind)", "native-token-life.s")
    state = expect_llvm(state, "Bag = Box { items = [], label = \"\" } skill keep(bag) { out bag } program() { @bag = Bag { items = [4, 7], label = \"candy\" } @same = keep(bag) out core.group.item(same.items, 1) }", "%Box_Bag = type { %Group, ptr }", "native-box-group.s")
    state = expect_llvm(state, "Token = Box { kind = \"\", value = \"\", line = 1, col = 1 } skill token_make(kind, value, line, col) { out Token { kind = kind, value = value, line = line, col = col } } program() { @token = token_make(\"NAME\", \"candy\", 7, 3) out core.io.show(token.value) }", "define void @token_make(ptr %kind, ptr %value, i32 %line, i32 %col, ptr %result)", "native-token-make.s")
    state = expect_llvm(state, "program() { @items = [7, \"sweet\", [4, 9], none] @picked = core.group.item(items, 1) out core.io.show(picked) }", "%Value = type { i32, i32, i64 }", "native-group-any.s")
    state = expect_llvm(state, "program() { @items = [7, \"sweet\", [4, 9], none] out core.group.count(items) }", "store i32 0, ptr %items_value_3_kind", "native-group-none.s")
    state = expect_llvm(state, "Token = Box { kind = \"\", value = \"\" } skill pick(tokens, index) { @token = core.group.item(tokens, index) out token } program() { @first = Token { kind = \"NAME\", value = \"candy\" } @second = Token { kind = \"WORD\", value = \"sweet\" } @tokens = [first, second] @picked = pick(tokens, 1) out core.io.show(picked.kind) }", "%item_valid = and i1 %item_is_box, %item_type_ok", "native-group-runtime-index.s")
    state = expect_llvm(state, "Token = Box { kind = \"\", value = \"\", line = 1, col = 1 } skill token_make(kind, value, line, col) { out Token { kind = kind, value = value, line = line, col = col } } skill scan_chars(source) { @tokens = [] @index = 0 @length = core.str.len(source) drum (length) { @ch = core.str.at(source, index) @token = token_make(\"CHAR\", ch, 1, index) @next = core.group.add(tokens, token) tokens = next index = index + 1 } out tokens } program() { @tokens = scan_chars(\"candy\") out core.group.count(tokens) }", "%scan_tokens = phi ptr", "native-scanner-slice.s")
    state = expect_llvm(state, "Token = Box { kind = \"\", value = \"\", line = 1, col = 1 } skill token_make(kind, value, line, col) { out Token { kind = kind, value = value, line = line, col = col } } skill scan_lex(source) { @tokens = [] @index = 0 @length = core.str.len(source) drum (length) { @part = core.str.slice(source, index, length) index = index + 1 } out tokens } program() { @tokens = scan_lex(\"program candy = 7\") out core.group.count(tokens) }", "%word_kind = select i1 %word_is_program", "native-scanner-lex.s")
    state = expect_llvm(state, "Token = Box { kind = \"\", value = \"\", line = 1, col = 1 } skill token_make(kind, value, line, col) { out Token { kind = kind, value = value, line = line, col = col } } skill scan_lex(source) { @tokens = [] @index = 0 @length = core.str.len(source) drum (length) { @part = core.str.slice(source, index, length) index = index + 1 } out tokens } program() { @tokens = scan_lex(\"rescue\") out core.group.count(tokens) }", "%word_kind_rescue = select", "native-scanner-keywords.s")
    state = expect_llvm(state, "Token = Box { kind = \"\", value = \"\", line = 1, col = 1 } skill token_make(kind, value, line, col) { out Token { kind = kind, value = value, line = line, col = col } } skill scan_lex(source) { @tokens = [] @index = 0 @length = core.str.len(source) drum (length) { @part = core.str.slice(source, index, length) index = index + 1 } out tokens } program() { @tokens = scan_lex(\"[\") out core.group.count(tokens) }", "%symbol_kind_lbracket = select", "native-scanner-symbols.s")
    tester_summary_state(state)
    out none
}
