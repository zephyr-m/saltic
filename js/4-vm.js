#!/usr/bin/env node

// RV32I — 40 instructions:
//
// Upper immediates: LUI, AUIPC
// Jumps:            JAL, JALR
// Branches:         BEQ, BNE, BLT, BGE, BLTU, BGEU
// Loads:            LB, LH, LW, LBU, LHU
// Stores:           SB, SH, SW
// Immediate:        ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
// Registers:        ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
// Memory order:     FENCE
// Environment:      ECALL, EBREAK

const fs = require('node:fs')
const path = require('node:path')

const DEFAULT_MEMORY_SIZE = 64 * 1024 * 1024
const DEFAULT_LOAD_ADDRESS = 0x1000
const DEFAULT_STEP_LIMIT = 100_000_000

class Trap extends Error {
  constructor(reason, pc, detail = '') {
    super(`${reason} at 0x${hex(pc)}${detail ? `: ${detail}` : ''}`)
    this.name = 'Trap'
    this.reason = reason
    this.pc = pc >>> 0
  }
}

class Memory {
  constructor(size = DEFAULT_MEMORY_SIZE) {
    this.bytes = new Uint8Array(size)
  }

  check(address, size = 1) {
    address >>>= 0
    if (address > this.bytes.length - size) {
      throw new RangeError(`memory access 0x${hex(address)}..0x${hex(address + size - 1)} is outside RAM`)
    }
    return address
  }

  load8(address) {
    return this.bytes[this.check(address)]
  }

  load16(address) {
    address = this.checkAligned(address, 2)
    return this.bytes[address] | (this.bytes[address + 1] << 8)
  }

  load32(address) {
    address = this.checkAligned(address, 4)
    return (this.bytes[address]
      | (this.bytes[address + 1] << 8)
      | (this.bytes[address + 2] << 16)
      | (this.bytes[address + 3] << 24)) >>> 0
  }

  store8(address, value) {
    this.bytes[this.check(address)] = value
  }

  store16(address, value) {
    address = this.checkAligned(address, 2)
    this.bytes[address] = value
    this.bytes[address + 1] = value >>> 8
  }

  store32(address, value) {
    address = this.checkAligned(address, 4)
    this.bytes[address] = value
    this.bytes[address + 1] = value >>> 8
    this.bytes[address + 2] = value >>> 16
    this.bytes[address + 3] = value >>> 24
  }

  copy(address, source) {
    address = this.check(address, source.length)
    this.bytes.set(source, address)
  }

  fill(address, size, value = 0) {
    address = this.check(address, size)
    this.bytes.fill(value, address, address + size)
  }

  checkAligned(address, alignment) {
    address = this.check(address, alignment)
    if (address % alignment !== 0) throw new RangeError(`misaligned ${alignment}-byte access at 0x${hex(address)}`)
    return address
  }

  readString(address, limit = 1024 * 1024) {
    const start = this.check(address)
    let end = start
    while (end < this.bytes.length && end - start < limit && this.bytes[end] !== 0) end++
    if (end === this.bytes.length || end - start === limit) throw new RangeError('unterminated guest string')
    return Buffer.from(this.bytes.subarray(start, end)).toString('utf8')
  }
}

class Host {
  constructor(options = {}) {
    this.root = path.resolve(options.root || process.cwd())
    this.input = options.input ?? 0
    this.output = options.output ?? 1
    this.error = options.error ?? 2
    this.nextFd = 3
    this.files = new Map([
      [0, { fd: this.input, position: null, close: false }],
      [1, { fd: this.output, position: null, close: false }],
      [2, { fd: this.error, position: null, close: false }],
    ])
  }

  call(machine) {
    const number = machine.reg(17)
    const args = [10, 11, 12, 13, 14, 15].map(index => machine.reg(index))
    let result
    try {
      result = this.dispatch(number, args, machine)
    } catch (error) {
      if (error instanceof Trap) throw error
      result = -1
      machine.lastHostError = error
    }
    machine.setReg(10, result)
  }

  dispatch(number, args, machine) {
    switch (number) {
      case 56: return this.open(machine, args[1], args[2], args[3]) // openat
      case 57: return this.close(args[0])
      case 62: return this.seek(args[0], args[1] | 0, args[2])
      case 63: return this.read(machine, args[0], args[1], args[2])
      case 64: return this.write(machine, args[0], args[1], args[2])
      case 93:
      case 94:
        machine.exitCode = args[0] & 0xff
        machine.halted = true
        machine.haltReason = 'exit'
        return 0
      default:
        throw new Trap('unsupported ecall', machine.pc, `number ${number}`)
    }
  }

  resolve(machine, address) {
    const name = machine.memory.readString(address)
    const target = path.resolve(this.root, name)
    if (target !== this.root && !target.startsWith(`${this.root}${path.sep}`)) {
      throw new Error(`path escapes VM root: ${name}`)
    }
    return target
  }

  open(machine, address, flags, mode) {
    const target = this.resolve(machine, address)
    const access = flags & 3
    let nodeFlags = access === 0 ? fs.constants.O_RDONLY : access === 1 ? fs.constants.O_WRONLY : fs.constants.O_RDWR
    if (flags & 0x40) nodeFlags |= fs.constants.O_CREAT
    if (flags & 0x80) nodeFlags |= fs.constants.O_EXCL
    if (flags & 0x200) nodeFlags |= fs.constants.O_TRUNC
    if (flags & 0x400) nodeFlags |= fs.constants.O_APPEND
    const fd = fs.openSync(target, nodeFlags, mode || 0o666)
    const guestFd = this.nextFd++
    this.files.set(guestFd, { fd, position: flags & 0x400 ? fs.fstatSync(fd).size : 0, close: true })
    return guestFd
  }

  close(guestFd) {
    const file = this.file(guestFd)
    if (file.close) fs.closeSync(file.fd)
    this.files.delete(guestFd)
    return 0
  }

  seek(guestFd, offset, whence) {
    const file = this.file(guestFd)
    if (file.position === null) throw new Error('file is not seekable')
    if (whence === 0) file.position = offset
    else if (whence === 1) file.position += offset
    else if (whence === 2) file.position = fs.fstatSync(file.fd).size + offset
    else throw new Error(`invalid whence ${whence}`)
    if (file.position < 0) throw new Error('negative file position')
    return file.position
  }

  read(machine, guestFd, address, count) {
    const file = this.file(guestFd)
    address = machine.memory.check(address, count)
    const buffer = Buffer.from(machine.memory.bytes.buffer, address, count)
    const read = fs.readSync(file.fd, buffer, 0, count, file.position)
    if (file.position !== null) file.position += read
    return read
  }

  write(machine, guestFd, address, count) {
    const file = this.file(guestFd)
    address = machine.memory.check(address, count)
    const buffer = Buffer.from(machine.memory.bytes.buffer, address, count)
    const written = fs.writeSync(file.fd, buffer, 0, count, file.position)
    if (file.position !== null) file.position += written
    return written
  }

  file(guestFd) {
    const file = this.files.get(guestFd)
    if (!file) throw new Error(`bad file descriptor ${guestFd}`)
    return file
  }

  dispose() {
    for (const file of this.files.values()) {
      if (file.close) {
        try { fs.closeSync(file.fd) } catch {}
      }
    }
    this.files.clear()
  }
}

class Machine {
  constructor(options = {}) {
    this.memory = options.memory || new Memory(options.memorySize)
    this.host = options.host || new Host(options)
    this.registers = new Uint32Array(32)
    this.pc = 0
    this.halted = false
    this.haltReason = null
    this.exitCode = 0
    this.steps = 0
    this.lastHostError = null
  }

  reg(index) {
    return index === 0 ? 0 : this.registers[index] >>> 0
  }

  signed(index) {
    return this.reg(index) | 0
  }

  setReg(index, value) {
    if (index !== 0) this.registers[index] = value >>> 0
  }

  load(program, options = {}) {
    const image = Buffer.isBuffer(program) ? program : Buffer.from(program)
    const loaded = isElf(image)
      ? loadElf(image, this.memory)
      : loadFlat(image, this.memory, options.address ?? DEFAULT_LOAD_ADDRESS)
    this.pc = options.entry ?? loaded.entry
    this.prepareStack(options.args || [], options.programName || 'program')
    return loaded
  }

  prepareStack(args, programName) {
    const values = [programName, ...args].map(String)
    let cursor = (this.memory.bytes.length - 16) & ~15
    const addresses = []
    for (let index = values.length - 1; index >= 0; index--) {
      const bytes = Buffer.from(`${values[index]}\0`)
      cursor -= bytes.length
      this.memory.copy(cursor, bytes)
      addresses[index] = cursor
    }
    const stack = (cursor - (values.length + 2) * 4) & ~15
    const argv = stack + 4
    this.memory.store32(stack, values.length)
    addresses.forEach((address, index) => this.memory.store32(argv + index * 4, address))
    this.memory.store32(argv + addresses.length * 4, 0)
    this.setReg(2, stack)
    this.setReg(10, values.length)
    this.setReg(11, argv)
  }

  step() {
    if (this.halted) return
    if (this.pc & 3) throw new Trap('instruction address misaligned', this.pc)

    let instruction
    try {
      instruction = this.memory.load32(this.pc)
    } catch (error) {
      throw new Trap('instruction access fault', this.pc, error.message)
    }

    const currentPc = this.pc
    const opcode = instruction & 0x7f
    const rd = instruction >>> 7 & 0x1f
    const funct3 = instruction >>> 12 & 7
    const rs1 = instruction >>> 15 & 0x1f
    const rs2 = instruction >>> 20 & 0x1f
    const funct7 = instruction >>> 25
    let nextPc = (currentPc + 4) >>> 0

    const illegal = detail => { throw new Trap('illegal instruction', currentPc, detail || `0x${hex(instruction)}`) }
    const address = immediate => (this.reg(rs1) + immediate) >>> 0
    const load = (size, signed) => {
      try {
        const value = size === 1 ? this.memory.load8(address(immI(instruction)))
          : size === 2 ? this.memory.load16(address(immI(instruction)))
            : this.memory.load32(address(immI(instruction)))
        return signed ? signExtend(value, size * 8) : value >>> 0
      } catch (error) {
        throw new Trap('load access fault', currentPc, error.message)
      }
    }
    const store = (size, value) => {
      try {
        const target = address(immS(instruction))
        if (size === 1) this.memory.store8(target, value)
        else if (size === 2) this.memory.store16(target, value)
        else this.memory.store32(target, value)
      } catch (error) {
        throw new Trap('store access fault', currentPc, error.message)
      }
    }

    switch (opcode) {
      case 0x37: // LUI
        this.setReg(rd, instruction & 0xfffff000)
        break
      case 0x17: // AUIPC
        this.setReg(rd, currentPc + (instruction & 0xfffff000))
        break
      case 0x6f: // JAL
        this.setReg(rd, nextPc)
        nextPc = (currentPc + immJ(instruction)) >>> 0
        break
      case 0x67: // JALR
        if (funct3 !== 0) illegal()
        {
          const target = address(immI(instruction)) & ~1
          this.setReg(rd, nextPc)
          nextPc = target >>> 0
        }
        break
      case 0x63: { // branches
        const left = this.reg(rs1)
        const right = this.reg(rs2)
        const take = funct3 === 0 ? left === right
          : funct3 === 1 ? left !== right
            : funct3 === 4 ? (left | 0) < (right | 0)
              : funct3 === 5 ? (left | 0) >= (right | 0)
                : funct3 === 6 ? left < right
                  : funct3 === 7 ? left >= right
                    : illegal()
        if (take) nextPc = (currentPc + immB(instruction)) >>> 0
        break
      }
      case 0x03: // loads
        if (funct3 === 0) this.setReg(rd, load(1, true))
        else if (funct3 === 1) this.setReg(rd, load(2, true))
        else if (funct3 === 2) this.setReg(rd, load(4, true))
        else if (funct3 === 4) this.setReg(rd, load(1, false))
        else if (funct3 === 5) this.setReg(rd, load(2, false))
        else illegal()
        break
      case 0x23: // stores
        if (funct3 === 0) store(1, this.reg(rs2))
        else if (funct3 === 1) store(2, this.reg(rs2))
        else if (funct3 === 2) store(4, this.reg(rs2))
        else illegal()
        break
      case 0x13: { // immediate arithmetic
        const left = this.reg(rs1)
        const immediate = immI(instruction)
        if (funct3 === 0) this.setReg(rd, left + immediate) // ADDI
        else if (funct3 === 2) this.setReg(rd, (left | 0) < immediate ? 1 : 0) // SLTI
        else if (funct3 === 3) this.setReg(rd, left < (immediate >>> 0) ? 1 : 0) // SLTIU
        else if (funct3 === 4) this.setReg(rd, left ^ immediate) // XORI
        else if (funct3 === 6) this.setReg(rd, left | immediate) // ORI
        else if (funct3 === 7) this.setReg(rd, left & immediate) // ANDI
        else if (funct3 === 1 && funct7 === 0) this.setReg(rd, left << rs2) // SLLI
        else if (funct3 === 5 && funct7 === 0) this.setReg(rd, left >>> rs2) // SRLI
        else if (funct3 === 5 && funct7 === 0x20) this.setReg(rd, (left | 0) >> rs2) // SRAI
        else illegal()
        break
      }
      case 0x33: { // register arithmetic
        const left = this.reg(rs1)
        const right = this.reg(rs2)
        if (funct3 === 0 && funct7 === 0) this.setReg(rd, left + right) // ADD
        else if (funct3 === 0 && funct7 === 0x20) this.setReg(rd, left - right) // SUB
        else if (funct3 === 1 && funct7 === 0) this.setReg(rd, left << (right & 31)) // SLL
        else if (funct3 === 2 && funct7 === 0) this.setReg(rd, (left | 0) < (right | 0) ? 1 : 0) // SLT
        else if (funct3 === 3 && funct7 === 0) this.setReg(rd, left < right ? 1 : 0) // SLTU
        else if (funct3 === 4 && funct7 === 0) this.setReg(rd, left ^ right) // XOR
        else if (funct3 === 5 && funct7 === 0) this.setReg(rd, left >>> (right & 31)) // SRL
        else if (funct3 === 5 && funct7 === 0x20) this.setReg(rd, (left | 0) >> (right & 31)) // SRA
        else if (funct3 === 6 && funct7 === 0) this.setReg(rd, left | right) // OR
        else if (funct3 === 7 && funct7 === 0) this.setReg(rd, left & right) // AND
        else illegal()
        break
      }
      case 0x0f: // FENCE
        if (funct3 !== 0) illegal()
        break
      case 0x73:
        if (instruction === 0x00000073) this.host.call(this) // ECALL
        else if (instruction === 0x00100073) { // EBREAK
          this.halted = true
          this.haltReason = 'break'
        } else illegal()
        break
      default:
        illegal()
    }

    this.pc = nextPc
    this.registers[0] = 0
    this.steps++
  }

  run(options = {}) {
    const limit = options.steps ?? DEFAULT_STEP_LIMIT
    try {
      while (!this.halted && this.steps < limit) this.step()
      if (!this.halted) throw new Trap('step limit reached', this.pc, `${limit} instructions`)
      return this.result()
    } finally {
      if (options.keepFiles !== true) this.host.dispose()
    }
  }

  result() {
    return {
      exitCode: this.exitCode,
      reason: this.haltReason,
      pc: this.pc >>> 0,
      steps: this.steps,
      registers: Array.from(this.registers, value => value >>> 0),
    }
  }
}

function signExtend(value, bits) {
  return value << (32 - bits) >> (32 - bits)
}

function immI(word) {
  return word >> 20
}

function immS(word) {
  return signExtend(((word >>> 25) << 5) | ((word >>> 7) & 0x1f), 12)
}

function immB(word) {
  return signExtend(((word >>> 31) << 12)
    | (((word >>> 7) & 1) << 11)
    | (((word >>> 25) & 0x3f) << 5)
    | (((word >>> 8) & 0x0f) << 1), 13)
}

function immJ(word) {
  return signExtend(((word >>> 31) << 20)
    | (((word >>> 12) & 0xff) << 12)
    | (((word >>> 20) & 1) << 11)
    | (((word >>> 21) & 0x3ff) << 1), 21)
}

function isElf(image) {
  return image.length >= 4 && image[0] === 0x7f && image[1] === 0x45 && image[2] === 0x4c && image[3] === 0x46
}

function loadFlat(image, memory, address) {
  memory.copy(address, image)
  return { format: 'flat', entry: address >>> 0, segments: 1 }
}

function loadElf(image, memory) {
  if (image.length < 52) throw new Error('ELF header is truncated')
  if (image[4] !== 1) throw new Error('only ELF32 is supported')
  if (image[5] !== 1) throw new Error('only little-endian ELF is supported')
  if (image.readUInt16LE(18) !== 243) throw new Error('ELF machine is not RISC-V')

  const entry = image.readUInt32LE(24)
  const table = image.readUInt32LE(28)
  const entrySize = image.readUInt16LE(42)
  const count = image.readUInt16LE(44)
  let segments = 0

  for (let index = 0; index < count; index++) {
    const header = table + index * entrySize
    if (header + 32 > image.length) throw new Error('ELF program header is truncated')
    if (image.readUInt32LE(header) !== 1) continue
    const offset = image.readUInt32LE(header + 4)
    const virtualAddress = image.readUInt32LE(header + 8)
    const fileSize = image.readUInt32LE(header + 16)
    const memorySize = image.readUInt32LE(header + 20)
    if (fileSize > memorySize || offset + fileSize > image.length) throw new Error('invalid ELF load segment')
    memory.copy(virtualAddress, image.subarray(offset, offset + fileSize))
    if (memorySize > fileSize) memory.fill(virtualAddress + fileSize, memorySize - fileSize)
    segments++
  }

  if (segments === 0) throw new Error('ELF contains no loadable segments')
  return { format: 'elf', entry, segments }
}

function hex(value) {
  return (value >>> 0).toString(16).padStart(8, '0')
}

function parseCli(args) {
  const options = { args: [] }
  let file = null
  for (let index = 0; index < args.length; index++) {
    const arg = args[index]
    if (arg === '--') {
      options.args.push(...args.slice(index + 1))
      break
    }
    if (arg === '--memory') options.memorySize = Number(args[++index])
    else if (arg === '--steps') options.steps = Number(args[++index])
    else if (arg === '--root') options.root = args[++index]
    else if (arg === '--address') options.address = Number(args[++index])
    else if (!file) file = arg
    else options.args.push(arg)
  }
  if (!file) throw new Error('usage: node js/4-vm.js <program.elf|program.bin> [--root folder] [--steps count] [-- args...]')
  return { file, options }
}

function runFile(file, options = {}) {
  const machine = new Machine(options)
  machine.load(fs.readFileSync(file), {
    address: options.address,
    args: options.args,
    programName: file,
  })
  return machine.run({ steps: options.steps })
}

module.exports = {
  DEFAULT_LOAD_ADDRESS,
  Host,
  Machine,
  Memory,
  Trap,
  loadElf,
  loadFlat,
  runFile,
}

if (require.main === module) {
  try {
    const { file, options } = parseCli(process.argv.slice(2))
    const result = runFile(file, options)
    process.exitCode = result.exitCode
  } catch (error) {
    console.error(error.message)
    process.exitCode = 1
  }
}
