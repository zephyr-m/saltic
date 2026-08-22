#!/usr/bin/env node

const fs = require('node:fs')
const path = require('node:path')
const { Host, Machine } = require('../js/4-vm')

const MEMORY_SIZE = 256 * 1024
const NORMAL_STEP_LIMIT = 100_000
const SHORT_STEP_LIMIT = 32

function byteGroup(file) {
  return `[${Array.from(fs.readFileSync(file)).join(', ')}]`
}

function byteChunks(file) {
  const bytes = fs.readFileSync(file)
  const chunks = []
  for (let offset = 0; offset < bytes.length; offset += 256) {
    chunks.push(`[${Array.from(bytes.subarray(offset, offset + 256)).join(', ')}]`)
  }
  return `[${chunks.join(', ')}]`
}

function build(output, elf, flat, input) {
  const fixtures = `VM_TEST_ELF = ${byteChunks(elf)}\nVM_TEST_FLAT = ${byteChunks(flat)}\nVM_TEST_INPUT = ${byteGroup(input)}\n`
const entry = String.raw`use core
use s2.vm
use s2.vm.state

skill vm_test_numbers(values) {
    @text = ""
    @index = 0
    @count = core.group.count(values)
    drum (count) {
        (index > 0) { text = core.str.add(text, ",") }
        text = core.str.add(text, core.num.text(core.group.at(values, index)))
        index = index + 1
    }
    out text
}

skill vm_test_strings(values) {
    @text = ""
    @index = 0
    @count = core.group.count(values)
    drum (count) {
        (index > 0) { text = core.str.add(text, ",") }
        text = core.str.add(text, core.group.at(values, index))
        index = index + 1
    }
    out text
}

skill vm_test_output(files) {
    @bytes = []
    @index = 0
    @count = core.group.count(files)
    drum (count) {
        @file = core.group.at(files, index)
        (file.path == "output.txt") { bytes = file.data }
        index = index + 1
    }
    out bytes
}

skill vm_test_snapshot(result) {
    @text = core.str.add("exit_code=", core.num.text(result.exit_code))
    text = core.str.add(text, "\nreason=")
    text = core.str.add(text, result.reason)
    text = core.str.add(text, "\npc=")
    text = core.str.add(text, result.pc)
    text = core.str.add(text, "\nsteps=")
    text = core.str.add(text, core.num.text(result.steps))
    text = core.str.add(text, "\nregisters=")
    text = core.str.add(text, vm_test_strings(result.registers))
    text = core.str.add(text, "\nstdout=")
    text = core.str.add(text, vm_test_numbers(result.stdout))
    text = core.str.add(text, "\nstderr=")
    text = core.str.add(text, vm_test_numbers(result.stderr))
    text = core.str.add(text, "\noutput=")
    text = core.str.add(text, vm_test_numbers(vm_test_output(result.files)))
    text = core.str.add(text, "\ntrap=")
    text = core.str.add(text, result.trap)
    out core.str.add(text, "\n")
}

program(image_format, scenario, snapshot_path) {
    @image = VM_TEST_ELF
    (image_format == "bin") { image = VM_TEST_FLAT }
    @arguments = [scenario]
    (scenario == "normal") { arguments = ["normal", "input.txt", "output.txt"] }
    @limit = 100000
    (scenario == "timeout") { limit = 32 }
    @options = state.Options {
        load_address = 4096
        memory_size = 262144
        step_limit = limit
        program_name = "vm-canonical"
        arguments = arguments
        files = [state.File { path = "input.txt" data = VM_TEST_INPUT }]
    }
    @result = vm.run(image, options)
    core.file.write(snapshot_path, vm_test_snapshot(result))
    out none
}
`
  fs.writeFileSync(output, `${fixtures}\n${entry}`)
}

function hex(value) {
  return (value >>> 0).toString(16).padStart(8, '0')
}

function argsFor(scenario) {
  return scenario === 'normal'
    ? ['normal', 'input.txt', 'output.txt']
    : [scenario]
}

function snapshot(machine, error, stdout, stderr, output) {
  return [
    `exit_code=${machine.exitCode}`,
    `reason=${error ? 'trap' : machine.haltReason}`,
    `pc=${hex(machine.pc)}`,
    `steps=${machine.steps}`,
    `registers=${Array.from(machine.registers, hex).join(',')}`,
    `stdout=${Array.from(stdout).join(',')}`,
    `stderr=${Array.from(stderr).join(',')}`,
    `output=${Array.from(output).join(',')}`,
    `trap=${error ? error.message : ''}`,
    '',
  ].join('\n')
}

function expected(imagePath, scenario, inputPath, root, outputPath) {
  fs.mkdirSync(root, { recursive: true })
  const guestInput = path.join(root, 'input.txt')
  const guestOutput = path.join(root, 'output.txt')
  const stdoutPath = path.join(root, 'stdout.bin')
  const stderrPath = path.join(root, 'stderr.bin')
  fs.copyFileSync(inputPath, guestInput)
  try { fs.unlinkSync(guestOutput) } catch (error) { if (error.code !== 'ENOENT') throw error }

  const stdoutFd = fs.openSync(stdoutPath, 'w')
  const stderrFd = fs.openSync(stderrPath, 'w')
  const host = new Host({ root, output: stdoutFd, error: stderrFd })
  const machine = new Machine({ host, memorySize: MEMORY_SIZE })
  let failure = null
  try {
    machine.load(fs.readFileSync(imagePath), {
      address: 0x1000,
      args: argsFor(scenario),
      programName: 'vm-canonical',
    })
    machine.run({ steps: scenario === 'timeout' ? SHORT_STEP_LIMIT : NORMAL_STEP_LIMIT })
  } catch (error) {
    failure = error
  } finally {
    host.dispose()
    fs.closeSync(stdoutFd)
    fs.closeSync(stderrFd)
  }

  const stdout = fs.readFileSync(stdoutPath)
  const stderr = fs.readFileSync(stderrPath)
  const guestResult = fs.existsSync(guestOutput) ? fs.readFileSync(guestOutput) : Buffer.alloc(0)
  fs.writeFileSync(outputPath, snapshot(machine, failure, stdout, stderr, guestResult))
}

const [command, ...args] = process.argv.slice(2)
if (command === 'build' && args.length === 4) build(...args)
else if (command === 'expected' && args.length === 5) expected(...args)
else {
  console.error('использование: vm-parity.js build <выход> <elf> <flat> <вход> | expected <образ> <сценарий> <вход> <корень> <выход>')
  process.exit(2)
}
