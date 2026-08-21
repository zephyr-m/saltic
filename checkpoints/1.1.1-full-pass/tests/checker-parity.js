#!/usr/bin/env node
const fs = require('node:fs')
const parser = require('../js/1-parser')
const checker = require('../js/2-checker')

function build(output) {
  const entry = `use core
use s2.parser
use s2.checker

program(path) {
    @loaded = parser.parser_load_file_loc(path, ".")
    (core.group.count(loaded.diagnostics) > 0) { out error.ParseFailed }
    @result = checker.checker_check(loaded.ast)
    @index = 0
    @count = core.group.count(result.diagnostics)
    drum (count) {
        @item = core.group.item(result.diagnostics, index)
        core.io.show(item.code, "|", item.line, "|", item.col, "|", item.message)
        index = index + 1
    }
    out none
}
`
  fs.writeFileSync(output, entry)
}

function expected(file) {
  for (const item of checker.checkDatum(parser.loadFile(file, { locations: true }))) {
    process.stdout.write(`${item.code}|${item.line ?? 0}|${item.col ?? 0}|${item.message}\n`)
  }
}

function ast(file) {
  process.stdout.write(`${JSON.stringify(parser.loadFile(file, { locations: true }), null, 2)}\n`)
}

const [command, value] = process.argv.slice(2)
if (command === 'build' && value) build(value)
else if (command === 'expected' && value) expected(value)
else if (command === 'ast' && value) ast(value)
else {
  console.error('использование: checker-parity.js build <выход> | ast <исходник> | expected <исходник>')
  process.exit(2)
}
