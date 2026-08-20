#!/usr/bin/env node
const fs = require('node:fs')
const path = require('node:path')

function withoutProgram(source, required = true) {
  const at = source.lastIndexOf('\nprogram(')
  if (at < 0) {
    if (required) throw new Error('точка входа program не найдена')
    return source
  }
  return `${source.slice(0, at)}\n`
}

function build(output) {
  const root = path.resolve(__dirname, '..')
  const parserSource = withoutProgram(fs.readFileSync(path.join(root, 's2/1-parser.s'), 'utf8'))
  let checkerSource = withoutProgram(fs.readFileSync(path.join(root, 's2/2-checker.s'), 'utf8'))
  const compilerSource = withoutProgram(fs.readFileSync(path.join(root, 's2/3-compiler.s'), 'utf8'), false)
  checkerSource = checkerSource.replace(/use core\n\nSalticNode = Box \{\n    datum = \[\]\n    tag = ""\n\}\n\n/, '')
  const entry = `
program(source_path, assembly_path) {
    @source = core.file.read(source_path)
    @parsed = parser_parse_string(source, source_path)
    (core.group.count(parsed.diagnostics) > 0) { out error.ParseFailed }
    @checked = checker_check(parsed.ast)
    (core.group.count(checked.diagnostics) > 0) { out error.CheckFailed }
    @assembly = compiler_compile(parsed.ast)
    core.file.write(assembly_path, assembly)
    out none
}
`
  fs.writeFileSync(output, parserSource + checkerSource + compilerSource + entry)
}

function expandHeap(input, output) {
  const source = fs.readFileSync(input, 'utf8')
  const marker = '.space 16777216'
  if (!source.includes(marker)) throw new Error('размер стандартного heap не найден в bootstrap assembly')
  fs.writeFileSync(output, source.replace(marker, '.space 50331648'))
}

const [command, value, extra] = process.argv.slice(2)
if (command === 'build' && value) build(value)
else if (command === 'expand-heap' && value && extra) expandHeap(value, extra)
else {
  console.error('использование: compiler-parity.js build <выход> | expand-heap <вход> <выход>')
  process.exit(2)
}
