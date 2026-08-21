#!/usr/bin/env node
const fs = require('node:fs')
const path = require('node:path')

function build(output) {
  const root = path.resolve(__dirname, '..')
  fs.copyFileSync(path.join(root, 's2/toolchain.saltic'), output)
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
