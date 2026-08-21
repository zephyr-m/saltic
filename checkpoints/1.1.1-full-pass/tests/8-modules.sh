#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cd "$root"
node - <<'NODE'
const parser = require('./js/1-parser')
const checker = require('./js/2-checker')

function loaded(path) {
    return parser.loadFile(path, { expandCore: false })
}

const ast = parser.loadFile('tests/modules/main.saltic', { expandCore: false })
const greeting = ast.slice(1).find(item => item[0] === 'skill' && item[1] === 'module_greeting')
if (!greeting) throw new Error('imported declaration is absent')
if (parser.moduleOf(greeting)?.join('.') !== 'nested.greeting') throw new Error('imported declaration lost its module')

const bare = checker.checkDatum(parser.astWithLocations(loaded('tests/modules/errors.saltic')))
if (!bare.some(item => item.code === 'unknown_name' && item.message.includes('module_greeting'))) {
    throw new Error('imported declaration leaked into the root module')
}
NODE
nix-shell -p pkgsCross.riscv32-embedded.buildPackages.gcc \
    --run "node js/3-compiler.js tests/modules/main.saltic '$work/modules.elf'"
node js/4-vm.js "$work/modules.elf" >"$work/stdout.txt"

diff -u tests/expected/modules.txt "$work/stdout.txt"

echo "modules: ok"
