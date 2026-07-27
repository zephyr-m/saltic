use core
use s2.parser
use s.make.tester

program() {
    @state = tester_start()

    @source = "use core\nMode = enum { ready, done }\nPoint = Box { x = 0, y = 0 }\norigin = Point { x = 1 }\nskill work(a, b) {\n@items = [1, \"two\", yes, no, none, .ready]\na = a + b * 2\nout run(a) rescue |error| { out error }\n(a > 0) { out items }\n(a) { .ready => 1, .done => 2 }\ndrum (2) { ping() }\n}\nprogram(arg) { out work(arg, 3) }"
    @parsed = parser_parse_string(source, "contract.s")
    state = tester_expect_in(state, core.group.count(parsed.diagnostics), 0)

    @expected = [
        "program",
        ["use", "core"],
        ["enum", "Mode", "ready", "done"],
        ["box", "Point", ["field", "x", ["number", 0]], ["field", "y", ["number", 0]]],
        ["const", "origin", ["box-new", "Point", ["field", "x", ["number", 1]]]],
        ["skill", "work", ["a", "b"], ["block",
            ["var", "items", ["group", ["number", 1], ["string", "two"], ["answer", "yes"], ["answer", "no"], ["none"], ["enum-value", "ready"]]],
            ["assign", "a", ["binary", "+", ["path", "a"], ["binary", "*", ["path", "b"], ["number", 2]]]],
            ["out", ["rescue", ["call", ["path", "run"], ["path", "a"]], "error", ["block", ["out", ["path", "error"]]]]],
            ["if", ["binary", ">", ["path", "a"], ["number", 0]], ["block", ["out", ["path", "items"]]]],
            ["switch", ["path", "a"], ["case", "ready", ["number", 1]], ["case", "done", ["number", 2]]],
            ["drum", ["number", 2], ["block", ["expr", ["call", ["path", "ping"]]]]]
        ]],
        ["entry", ["arg"], ["block", ["out", ["call", ["path", "work"], ["path", "arg"], ["number", 3]]]]]
    ]
    state = tester_expect_in(state, parsed.ast, expected)

    @located = parser_parse_string_loc("program() {\n  out 1 + 2\n}", "loc.s")
    @located_expected = ["program",
        ["loc", 1, 1, ["entry", [],
            ["loc", 1, 11, ["block",
                ["loc", 2, 3, ["out",
                    ["loc", 2, 9, ["binary", "+",
                        ["loc", 2, 7, ["number", 1]],
                        ["loc", 2, 11, ["number", 2]]
                    ]]
                ]]
            ]]
        ]]
    ]
    state = tester_expect_in(state, located.ast, located_expected)

    @scan = parser_lex("α_2 12.5 == => \"a\\n\\t\\\"\\\\b\"", "lex.s")
    state = tester_expect_in(state, core.group.count(scan.diagnostics), 0)
    @token0 = core.group.item(scan.tokens, 0)
    @token1 = core.group.item(scan.tokens, 1)
    @token2 = core.group.item(scan.tokens, 2)
    @token3 = core.group.item(scan.tokens, 3)
    @token4 = core.group.item(scan.tokens, 4)
    state = tester_expect_in(state, token0.kind, "IDENT")
    state = tester_expect_in(state, token0.value, "α_2")
    state = tester_expect_in(state, token1.value, "12.5")
    state = tester_expect_in(state, token2.kind, "EQ")
    state = tester_expect_in(state, token3.kind, "ARROW")
    state = tester_expect_in(state, token4.value, "a\n\t\"\\b")

    @bad_lex = parser_parse_string("program() { out ? }", "bad.s")
    state = tester_expect_in(state, core.group.count(bad_lex.diagnostics), 1)
    @bad_parse = parser_parse_string("program() { out ] }", "bad.s")
    state = tester_expect_in(state, core.group.count(bad_parse.diagnostics), 1)


    @ok = tester_summary_state(state)
    out ok
}
