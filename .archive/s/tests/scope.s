use s.make.compiler.semantics.scope
use s.make.tester

program() {
    @state = tester_start()
    @scope = scope_start()
    state = tester_expect_in(state, scope_has(scope, "value"), no)

    scope = scope_put(scope, "value", 7)
    state = tester_expect_in(state, scope_has(scope, "value"), yes)
    @lookup = scope_get(scope, "value")
    state = tester_expect_in(state, lookup.found, yes)
    state = tester_expect_in(state, lookup.value, 7)

    scope = scope_put(scope, "value", 9)
    @updated = scope_get(scope, "value")
    state = tester_expect_in(state, updated.value, 9)

    @parent = scope_start()
    parent = scope_put(parent, "outer", 7)
    @child = scope_child(parent)
    state = tester_expect_in(state, scope_has(child, "outer"), yes)
    @inherited = scope_get(child, "outer")
    state = tester_expect_in(state, inherited.value, 7)
    child = scope_put(child, "outer", 9)
    @shadowed = scope_get(child, "outer")
    @unchanged = scope_get(parent, "outer")
    state = tester_expect_in(state, shadowed.value, 9)
    state = tester_expect_in(state, unchanged.value, 7)

    tester_summary_state(state)
    out none
}
