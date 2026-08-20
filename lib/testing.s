use core

Testing = Box {
    passed = 0
    failed = 0
}

skill testing_new() {
    out Testing {}
}

skill testing_pass(testing, name) {
    testing.passed = testing.passed + 1
    core.io.show("проверка пройдена: ", name)
    out testing
}

skill testing_fail(testing, name, actual, expected) {
    testing.failed = testing.failed + 1
    core.io.show("проверка провалена: ", name)
    core.io.show("  получено: ", actual)
    core.io.show("  ожидалось: ", expected)
    out testing
}

skill test_equal(testing, name, actual, expected) {
    (actual == expected) {
        out testing_pass(testing, name)
    }
    out testing_fail(testing, name, actual, expected)
}

skill test_yes(testing, name, actual) {
    out test_equal(testing, name, actual, yes)
}

skill test_no(testing, name, actual) {
    out test_equal(testing, name, actual, no)
}

skill testing_summary(testing) {
    core.io.show("проверок пройдено: ", testing.passed)
    core.io.show("проверок провалено: ", testing.failed)
    out testing.failed
}

skill testing_finish(testing) {
    testing_summary(testing)
    (testing.failed > 0) {
        out error.TestsFailed
    }
    out none
}
