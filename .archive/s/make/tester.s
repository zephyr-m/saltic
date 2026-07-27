use core

TesterContract = Box {
    name = "tester"
    version = "0.1"
}

TesterState = Box {
    passed = 0
    failed = 0
}

skill tester_contract() {
    out TesterContract {}
}

skill tester_start() {
    out TesterState {}
}

skill tester_record(state, passed) {
    (passed == yes) {
        out TesterState {
            passed = state.passed + 1
            failed = state.failed
        }
    }
    out TesterState {
        passed = state.passed
        failed = state.failed + 1
    }
}

skill tester_expect_in(state, actual, expected) {
    @passed = tester_expect(actual, expected)
    out tester_record(state, passed)
}

skill tester_summary_state(state) {
    core.io.show("tester passed=", state.passed)
    core.io.show("tester failed=", state.failed)
    out state.failed == 0
}

skill tester_expect(actual, expected) {
    (actual == expected) {
        core.io.show("pass expect")
        out yes
    }
    core.io.show("fail expect")
    out no
}

skill tester_ok(value) {
    (value == yes) {
        core.io.show("pass ok")
        out yes
    }
    core.io.show("fail ok")
    out no
}

skill tester_fail(value) {
    (value == no) {
        core.io.show("pass fail")
        out yes
    }
    core.io.show("fail fail")
    out no
}

skill tester_equal(left, right) {
    out tester_expect(left, right)
}

skill tester_summary() {
    core.io.show("tester summary")
    out yes
}
