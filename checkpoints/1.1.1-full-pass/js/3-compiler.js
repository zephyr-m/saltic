#!/usr/bin/env node

// Saltic syntax tree to RV32I ELF.

const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const child = require('node:child_process')
const parser = require('./1-parser')
const checker = require('./2-checker')

const TAG = {
  number: 0,
  answer: 1,
  none: 2,
  string: 3,
  group: 4,
  box: 5,
  enum: 6,
  error: 7,
}

const NO = TAG.answer
const YES = (1 << 3) | TAG.answer
const NONE = TAG.none
const FIXED_KIND = { u8: 1, u16: 2, u32: 3, i32: 4, bits32: 5, address: 6, usize: 7 }
const FIXED_TYPES = new Set(Object.keys(FIXED_KIND))

function constantInteger(node) {
  if (node?.[0] === 'number') return node[1]
  if (node?.[0] === 'wide-number') return Number(node[1])
  if (node?.[0] === 'binary' && node[1] === '-') {
    const left = constantInteger(node[2]), right = constantInteger(node[3])
    if (left !== null && right !== null) return left - right
  }
  return null
}

class Compiler {
  constructor(ast) {
    this.ast = ast
    this.lines = []
    this.data = []
    this.serial = 0
    this.strings = new Map()
    this.constants = new Map()
    this.constantModules = new Map()
    this.boxes = new Map()
    this.boxModules = new Map()
    this.enums = new Map()
    this.variants = new Map()
    this.errors = new Map()
    this.fields = new Map()
    this.skills = new Map()
    this.aliases = new Map()
    this.subjectSkills = new Map()
    this.entry = null
    this.function = null
    this.collectTopLevel()
  }

  collectTopLevel() {
    let enumId = 1
    let fieldId = 1
    for (const item of this.ast.slice(1)) {
      const module = parser.moduleOf(item) ?? []
      const topName = name => [...module, name].join('.')
      if (item[0] === 'use') {
        const imported = item.slice(1)
        const aliases = this.aliases.get(module.join('.')) ?? new Map()
        aliases.set(imported.at(-1), imported.join('.'))
        this.aliases.set(module.join('.'), aliases)
      }
      if (item[0] === 'const') { this.constants.set(topName(item[1]), item[2]); this.constantModules.set(topName(item[1]), module) }
      if (item[0] === 'box') {
        const name = topName(item[1])
        this.boxModules.set(name, module)
        const fields = item.slice(2).filter(member => member[0] === 'field')
        const skills = item.slice(2).filter(member => member[0] === 'subject-skill')
        this.boxes.set(name, fields)
        this.subjectSkills.set(name, new Map(skills.map(skill => [skill[1], skill])))
        for (const field of fields) {
          if (!this.fields.has(field[1])) this.fields.set(field[1], fieldId++)
        }
      }
      if (item[0] === 'enum') {
        const name = topName(item[1])
        this.enums.set(name, item.slice(2))
        for (const variant of item.slice(2)) {
          const value = (enumId++ << 3) | TAG.enum
          this.variants.set(`${name}.${variant}`, value)
          if (!this.variants.has(variant)) this.variants.set(variant, value)
        }
      }
      if (item[0] === 'skill') {
        this.skills.set(topName(item[1]), item)
      }
      if (item[0] === 'entry' && (parser.moduleOf(item)?.length ?? 0) === 0) this.entry = item
    }
    if (!this.entry) throw new Error('compile: program() is missing')
  }

  resolve(symbols, name, module = this.function?.module ?? []) {
    if (symbols.has(name)) return name
    const local = [...module, name].join('.')
    if (symbols.has(local)) return local
    const parts = name.split('.')
    const alias = this.aliases.get(module.join('.'))?.get(parts[0])
    const imported = alias ? [alias, ...parts.slice(1)].join('.') : null
    return imported && symbols.has(imported) ? imported : null
  }

  resolvePrefix(symbols, parts, module = this.function?.module ?? []) {
    for (let count = parts.length; count > 0; count--) {
      const name = this.resolve(symbols, parts.slice(0, count).join('.'), module)
      if (name) return { name, count }
    }
    return null
  }

  compile() {
    this.emit('.option norvc', '.option norelax', '.section .text', '.global _start', '')
    this.compileStart()
    for (const [name, skill] of this.skills) this.compileFunction(name, skill[2], skill[3], null, parser.moduleOf(skill) ?? [])
    for (const [box, skills] of this.subjectSkills) {
      for (const skill of skills.values()) this.compileFunction(`${box}.${skill[1]}`, ['$self', ...skill[2]], skill[3], box, this.boxModules.get(box) ?? [])
    }
    this.compileFunction('program', this.entry[1], this.entry[2])
    this.emit(runtimeAssembly())
    this.emit('.section .rodata', '.balign 8')
    this.emit(this.data.join('\n'))
    this.emit('.section .bss', '.balign 8', 'saltic_heap:', '.space 16777216', 'saltic_heap_end:')
    return `${this.lines.join('\n')}\n`
  }

  compileStart() {
    const params = this.entry[1]
    this.emit('_start:', '  la s1, saltic_heap', '  la s2, saltic_heap_end')
    this.emit(`  addi t0, zero, ${params.length + 1}`, '  blt a0, t0, rt_missing_args')
    for (let index = 0; index < params.length; index++) {
      this.emit(`  lw a0, ${(index + 1) * 4}(a1)`, '  call rt_cstring')
      this.emit('  addi sp, sp, -4', '  sw a0, 0(sp)')
    }
    for (let index = 0; index < params.length; index++) {
      this.emit(`  lw a${index}, ${(params.length - index - 1) * 4}(sp)`)
    }
    if (params.length) this.emit(`  addi sp, sp, ${params.length * 4}`)
    this.emit('  call saltic_program', '  andi t0, a0, 7', `  addi t1, zero, ${TAG.error}`, '  sub a0, t0, t1', '  sltu a0, zero, a0', '  xori a0, a0, 1', '  call rt_platform_exit', '')
  }

  compileFunction(name, params, body, subject = null, module = []) {
    const locals = collectLocals(params, body)
    const frame = align16((locals.size + 2) * 4)
    const slots = new Map()
    let slot = -12
    for (const local of locals) {
      slots.set(local, slot)
      slot -= 4
    }
    const end = this.label(`${name}_return`)
    this.function = { name, slots, end, drums: new Map(), subject, module, types: new Map(params.map(param => [param, 'unknown'])) }
    if (subject) this.function.types.set('$self', ['box', subject])
    this.emit(`saltic_${safe(name)}:`, `  addi sp, sp, -${frame}`, `  sw ra, ${frame - 4}(sp)`, `  sw s0, ${frame - 8}(sp)`, `  addi s0, sp, ${frame}`)
    params.forEach((param, index) => this.emit(`  sw a${index}, ${slots.get(param)}(s0)`))
    this.compileBlock(body)
    this.emit(`  addi a0, zero, ${NONE}`, `  j ${end}`, `${end}:`, `  lw ra, -4(s0)`, `  lw t0, -8(s0)`, '  addi sp, s0, 0', '  addi s0, t0, 0', '  jalr zero, 0(ra)', '')
    this.function = null
  }

  compileBlock(block, value = false) {
    const statements = block.slice(1)
    for (let index = 0; index < statements.length; index++) {
      const last = value && index === statements.length - 1
      this.compileStatement(statements[index], last)
    }
    if (value && statements.length === 0) this.emit(`  addi a0, zero, ${NONE}`)
  }

  compileStatement(node, keep = false) {
    const tag = node[0]
    if (tag === 'var' || tag === 'assign') {
      this.compileExpression(node[2])
      this.emit(`  sw a0, ${this.slot(node[1])}(s0)`)
      const type = this.inferType(node[2])
      if (type !== 'unknown' || !this.function.types.has(node[1])) this.function.types.set(node[1], type)
      return
    }
    if (tag === 'field-assign') {
      const parts = node[1].slice(1)
      this.compilePath(parts.slice(0, -1))
      this.push('a0')
      this.compileExpression(node[2])
      this.emit('  addi a2, a0, 0')
      this.pop('a0')
      this.loadImmediate('a1', this.field(parts.at(-1)))
      this.emit('  call rt_box_set')
      return
    }
    if (tag === 'out') {
      this.compileExpression(node[1])
      this.emit(`  j ${this.function.end}`)
      return
    }
    if (tag === 'expr') {
      this.compileExpression(node[1])
      return
    }
    if (tag === 'if') {
      const end = this.label('if_end')
      this.compileExpression(node[1])
      this.emit(`  addi t0, zero, ${NO}`, `  beq a0, t0, ${end}`, `  addi t0, zero, ${NONE}`, `  beq a0, t0, ${end}`, `  beq a0, zero, ${end}`)
      this.compileBlock(node[2], keep)
      this.emit(`${end}:`)
      return
    }
    if (tag === 'switch') {
      const end = this.label('switch_end')
      this.compileExpression(node[1])
      this.emit('  addi t2, a0, 0')
      for (const item of node.slice(2)) {
        const next = this.label('case_next')
        const value = this.variants.get(item[1])
        if (value === undefined) throw new Error(`compile: unknown enum variant .${item[1]}`)
        this.loadImmediate('t0', value)
        this.emit(`  bne t2, t0, ${next}`)
        this.compileExpression(item[2])
        this.emit(`  j ${end}`, `${next}:`)
      }
      this.emit(`${end}:`)
      return
    }
    if (tag === 'drum') {
      const counter = this.function.slots.get(`$drum:${nodeId(node)}`)
      const start = this.label('drum')
      const end = this.label('drum_end')
      this.compileExpression(node[1])
      this.emit('  srai a0, a0, 3', `  sw a0, ${counter}(s0)`, `${start}:`, `  lw t0, ${counter}(s0)`, `  beq t0, zero, ${end}`, '  addi t0, t0, -1', `  sw t0, ${counter}(s0)`)
      this.compileBlock(node[2])
      this.emit(`  j ${start}`, `${end}:`)
      return
    }
    throw new Error(`compile: unsupported statement ${tag}`)
  }

  compileExpression(node) {
    const tag = node[0]
    if (tag === 'number') return this.loadImmediate('a0', encodeNumber(node[1]))
    if (tag === 'string') return this.emit(`  la a0, ${this.string(node[1])}`, `  ori a0, a0, ${TAG.string}`)
    if (tag === 'answer') return this.loadImmediate('a0', node[1] === 'yes' ? YES : NO)
    if (tag === 'none') return this.loadImmediate('a0', NONE)
    if (tag === 'path') return this.compilePath(node.slice(1))
    if (tag === 'binary') return this.compileBinary(node[1], node[2], node[3])
    if (tag === 'call') return this.compileCall(node[1], node.slice(2))
    if (tag === 'group') return this.compileGroup(node.slice(1))
    if (tag === 'box-new') return this.compileBox(this.resolve(this.boxes, node[1]) ?? node[1], node.slice(2))
    if (tag === 'rescue') return this.compileRescue(node)
    if (tag === 'enum-value') {
      const value = this.variants.get(node[1])
      if (value === undefined) throw new Error(`compile: unknown enum variant .${node[1]}`)
      return this.loadImmediate('a0', value)
    }
    throw new Error(`compile: unsupported expression ${tag}`)
  }

  compilePath(parts) {
    if (parts[0] === 'error' && parts.length === 2) {
      if (parts[1] === 'FixedIntegerOverflow') return this.loadImmediate('a0', (6 << 3) | TAG.error)
      if (!this.errors.has(parts[1])) this.errors.set(parts[1], this.errors.size + 1)
      return this.loadImmediate('a0', (this.errors.get(parts[1]) << 3) | TAG.error)
    }
    const enumName = parts.length > 1 ? this.resolve(this.enums, parts.slice(0, -1).join('.')) : null
    if (enumName) return this.loadImmediate('a0', this.variants.get(`${enumName}.${parts.at(-1)}`))
    const name = parts[0]
    let consumed = 1
    if (this.function?.slots.has(name)) this.emit(`  lw a0, ${this.slot(name)}(s0)`)
    else if (this.resolvePrefix(this.constants, parts)) {
      const constant = this.resolvePrefix(this.constants, parts)
      consumed = constant.count
      const previous = this.function.module
      this.function.module = this.constantModules.get(constant.name) ?? previous
      this.compileExpression(this.constants.get(constant.name))
      this.function.module = previous
    }
    else if (this.function?.subject && this.boxes.get(this.function.subject).some(field => field[1] === name)) {
      this.emit(`  lw a0, ${this.slot('$self')}(s0)`)
      this.push('a0')
      this.loadImmediate('a1', this.field(name))
      this.pop('a0')
      this.emit('  call rt_box_get')
    }
    else throw new Error(`compile: unknown value ${name}`)
    for (const field of parts.slice(consumed)) {
      this.push('a0')
      this.loadImmediate('a1', this.field(field))
      this.pop('a0')
      this.emit('  call rt_box_get')
    }
  }

  compileBinary(operator, left, right) {
    this.compileExpression(left)
    this.push('a0')
    this.compileExpression(right)
    this.emit('  addi a1, a0, 0')
    this.pop('a0')
    const type = this.inferType(left)
    const fixedCalls = { '+': 'rt_fixed_add', '-': 'rt_fixed_sub', '*': 'rt_fixed_mul', '/': 'rt_fixed_div', '==': 'rt_fixed_equal', '>': 'rt_fixed_greater', '<': 'rt_fixed_less' }
    const calls = FIXED_TYPES.has(type) ? fixedCalls : { '+': 'rt_add', '-': 'rt_sub', '*': 'rt_mul', '/': 'rt_div', '==': 'rt_equal', '>': 'rt_greater', '<': 'rt_less' }
    this.emit(`  call ${calls[operator]}`)
  }

  compileCall(callee, args) {
    if (callee[0] !== 'path') throw new Error('compile: callable expression must be a path')
    const name = callee.slice(1).join('.')
    if (name === 'core.io.show') return this.compileShow(args)
    if (FIXED_TYPES.has(name)) {
      if (args.length !== 1) throw new Error(`compile: ${name} expects one argument`)
      const value = constantInteger(args[0])
      if (value !== null) this.emit(`  li a0, ${value}`)
      else {
        this.compileExpression(args[0])
        if (FIXED_TYPES.has(this.inferType(args[0]))) this.emit('  andi a0, a0, -8', '  lw a0, 0(a0)')
        else this.emit('  srai a0, a0, 3')
      }
      this.loadImmediate('a1', FIXED_KIND[name])
      this.emit('  call rt_fixed_new')
      return
    }
    const conversion = /^core\.(u8|u16|u32|i32|usize)\.from$/.exec(name)
    if (conversion) {
      this.compileArguments(args)
      this.loadImmediate('a1', FIXED_KIND[conversion[1]])
      this.emit('  call rt_fixed_convert')
      return
    }
    const fixedIntrinsic = {
      'core.bits32.and': 'rt_fixed_and', 'core.bits32.or': 'rt_fixed_or',
      'core.bits32.xor': 'rt_fixed_xor', 'core.bits32.not': 'rt_fixed_not',
      'core.bits32.shift_left': 'rt_fixed_shift_left', 'core.bits32.shift_right': 'rt_fixed_shift_right',
      'core.address.add': 'rt_fixed_add',
    }[name]
    if (fixedIntrinsic) { this.compileArguments(args); this.emit(`  call ${fixedIntrinsic}`); return }
    const typedMemory = /^core\.mem\.(load|store)(8|16|32)$/.exec(name)
    if (typedMemory && this.inferType(args[0]) === 'address') {
      this.compileArguments(args)
      this.emit(`  call rt_fixed_mem_${typedMemory[1]}${typedMemory[2]}`)
      return
    }
    if (callee.length === 2 && this.function?.subject && this.subjectSkills.get(this.function.subject)?.has(callee[1])) {
      this.compileArguments([['path', '$self'], ...args])
      this.emit(`  call saltic_${safe(`${this.function.subject}.${callee[1]}`)}`)
      return
    }
    const box = this.resolve(this.boxes, name)
    if (box) {
      if (args.length) throw new Error(`compile: ${name}() expects no arguments`)
      return this.compileBox(box, [])
    }
    if (callee.length === 3) {
      const receiver = ['path', callee[1]]
      const type = this.inferType(receiver)
      if (Array.isArray(type) && type[0] === 'box' && this.subjectSkills.get(type[1])?.has(callee[2])) {
        this.compileArguments([receiver, ...args])
        this.emit(`  call saltic_${safe(`${type[1]}.${callee[2]}`)}`)
        return
      }
    }
    const intrinsics = {
      'core.group.count': 'rt_group_count',
      'core.group.at': 'rt_group_at',
      'core.group.item': 'rt_group_at',
      'core.group.add': 'rt_group_add',
      'core.group.append': 'rt_group_add',
      'core.mem.load8': 'rt_mem_load8',
      'core.mem.load16': 'rt_mem_load16',
      'core.mem.load32': 'rt_mem_load32',
      'core.mem.store8': 'rt_mem_store8',
      'core.mem.store16': 'rt_mem_store16',
      'core.mem.store32': 'rt_mem_store32',
      'core.mem.store_address32': 'rt_mem_store_address32',
      'core.cpu.wait': 'rt_cpu_wait',
      'core.cpu.fence': 'rt_cpu_fence',
      'core.file.read': 'rt_file_read',
      'core.file.write': 'rt_file_write',
      'core.str.line_count': 'rt_line_count',
      'core.str.add': 'rt_string_add',
      'core.str.join': 'rt_string_add',
      'core.str.len': 'rt_string_len',
      'core.str.at': 'rt_string_at',
      'core.str.byte': 'rt_string_byte',
      'core.str.slice': 'rt_string_slice',
      'core.str.contains': 'rt_string_contains',
      'core.str.starts_with': 'rt_string_starts_with',
      'core.str.ends_with': 'rt_string_ends_with',
      'core.str.lower': 'rt_string_lower',
      'core.str.upper': 'rt_string_upper',
      'core.num.text': 'rt_number_text',
    }
    const skill = this.resolve(this.skills, name)
    const target = intrinsics[name] || (skill ? `saltic_${safe(skill)}` : null)
    if (!target) throw new Error(`compile: unsupported call ${name}`)
    this.compileArguments(args)
    this.emit(`  call ${target}`)
  }

  inferType(node) {
    if (!Array.isArray(node)) return 'unknown'
    if (node[0] === 'box-new') return ['box', this.resolve(this.boxes, node[1]) ?? node[1]]
    if (node[0] === 'path') {
      if (node.length === 2) return this.function?.types.get(node[1]) ?? 'unknown'
      const base = this.inferType(['path', node[1]])
      if (Array.isArray(base) && base[0] === 'box') {
        const field = this.boxes.get(base[1])?.find(item => item[1] === node[2])
        if (field?.[2]?.[0] === 'box-new') return ['box', field[2][1]]
      }
      return 'unknown'
    }
    if (node[0] === 'call' && node[1]?.[0] === 'path') {
      const callee = node[1]
      const name = callee.slice(1).join('.')
      if (FIXED_TYPES.has(name)) return name
      const conversion = /^core\.(u8|u16|u32|i32|usize)\.from$/.exec(name)
      if (conversion) return conversion[1]
      if (name.startsWith('core.bits32.')) return 'bits32'
      if (name === 'core.address.add') return 'address'
      if (name === 'core.mem.load8' && this.inferType(node[2]) === 'address') return 'u8'
      if (name === 'core.mem.load16' && this.inferType(node[2]) === 'address') return 'u16'
      if (name === 'core.mem.load32' && this.inferType(node[2]) === 'address') return 'u32'
      const box = this.resolve(this.boxes, name)
      if (box) return ['box', box]
    }
    if (node[0] === 'binary') {
      if (['==','>','<'].includes(node[1])) return 'answer'
      return this.inferType(node[2])
    }
    if (node[0] === 'rescue') return this.inferType(node[1])
    return 'unknown'
  }

  compileArguments(args) {
    if (args.length > 8) throw new Error('compile: at most 8 arguments are supported')
    for (const argument of args) {
      this.compileExpression(argument)
      this.push('a0')
    }
    args.forEach((_, index) => this.emit(`  lw a${index}, ${(args.length - index - 1) * 4}(sp)`))
    if (args.length) this.emit(`  addi sp, sp, ${args.length * 4}`)
  }

  compileShow(args) {
    for (const argument of args) {
      this.compileExpression(argument)
      this.emit(`  call ${FIXED_TYPES.has(this.inferType(argument)) ? 'rt_fixed_show' : 'rt_show'}`)
    }
    this.emit('  call rt_newline')
    this.loadImmediate('a0', NONE)
  }

  compileGroup(items) {
    for (const item of items) {
      this.compileExpression(item)
      this.push('a0')
    }
    this.loadImmediate('a0', align8(4 + items.length * 4))
    this.emit('  call rt_alloc', `  addi t3, zero, ${items.length}`, '  sw t3, 0(a0)')
    items.forEach((_, index) => this.emit(`  lw t0, ${(items.length - index - 1) * 4}(sp)`, `  sw t0, ${4 + index * 4}(a0)`))
    if (items.length) this.emit(`  addi sp, sp, ${items.length * 4}`)
    this.emit(`  ori a0, a0, ${TAG.group}`)
  }

  compileBox(name, overrides) {
    const model = this.boxes.get(name)
    if (!model) throw new Error(`compile: unknown Box ${name}`)
    const values = new Map(overrides.map(field => [field[1], field[2]]))
    for (const field of model) {
      const override = values.get(field[1])
      const previous = this.function.module
      if (!override) this.function.module = this.boxModules.get(name) ?? previous
      this.compileExpression(override ?? field[2])
      this.function.module = previous
      this.push('a0')
    }
    this.loadImmediate('a0', align8(4 + model.length * 8))
    this.emit('  call rt_alloc', `  addi t3, zero, ${model.length}`, '  sw t3, 0(a0)')
    model.forEach((field, index) => {
      this.loadImmediate('t0', this.field(field[1]))
      this.emit(`  sw t0, ${4 + index * 8}(a0)`, `  lw t0, ${(model.length - index - 1) * 4}(sp)`, `  sw t0, ${8 + index * 8}(a0)`)
    })
    if (model.length) this.emit(`  addi sp, sp, ${model.length * 4}`)
    this.emit(`  ori a0, a0, ${TAG.box}`)
  }

  compileRescue(node) {
    const done = this.label('rescue_done')
    this.compileExpression(node[1])
    this.emit('  andi t0, a0, 7', `  addi t1, zero, ${TAG.error}`, `  bne t0, t1, ${done}`, `  sw a0, ${this.slot(node[2])}(s0)`)
    this.compileBlock(node[3], true)
    this.emit(`${done}:`)
  }

  string(text) {
    if (this.strings.has(text)) return this.strings.get(text)
    const label = this.label('string')
    const bytes = Buffer.from(text)
    const values = [...bytes, 0].join(', ')
    this.data.push(`${label}:\n  .word ${bytes.length}\n  .byte ${values}\n  .balign 8`)
    this.strings.set(text, label)
    return label
  }

  field(name) {
    const value = this.fields.get(name)
    if (value === undefined) throw new Error(`compile: unknown field ${name}`)
    return value
  }

  slot(name) {
    const value = this.function.slots.get(name)
    if (value === undefined) throw new Error(`compile: unknown local ${name}`)
    return value
  }

  push(register) { this.emit('  addi sp, sp, -4', `  sw ${register}, 0(sp)`) }
  pop(register) { this.emit(`  lw ${register}, 0(sp)`, '  addi sp, sp, 4') }
  loadImmediate(register, value) { this.emit(`  li ${register}, ${value | 0}`) }
  label(prefix) { return `.L_${safe(prefix)}_${this.serial++}` }
  emit(...lines) { this.lines.push(...lines) }
}

let nextNodeId = 1
const nodeIds = new WeakMap()
function nodeId(node) {
  if (!nodeIds.has(node)) nodeIds.set(node, nextNodeId++)
  return nodeIds.get(node)
}

function collectLocals(params, body) {
  const names = new Set(params)
  function walk(node) {
    if (!Array.isArray(node)) return
    if (node[0] === 'var') names.add(node[1])
    if (node[0] === 'rescue') names.add(node[2])
    if (node[0] === 'drum') names.add(`$drum:${nodeId(node)}`)
    node.forEach(walk)
  }
  walk(body)
  return names
}

function encodeNumber(value) {
  if (!Number.isInteger(value) || value < -268435456 || value > 268435455) throw new Error(`compile: number ${value} is outside tagged RV32I range`)
  return (value << 3) | TAG.number
}

function align8(value) { return (value + 7) & ~7 }
function align16(value) { return (value + 15) & ~15 }
function safe(value) { return value.replace(/[^A-Za-z0-9_]/g, '_') }

function runtimeAssembly() {
  return `
rt_alloc:
  addi a0, a0, 7
  andi a0, a0, -8
  add t0, s1, a0
  bgtu t0, s2, rt_out_of_memory
  addi a0, s1, 0
  addi s1, t0, 0
  jalr zero, 0(ra)

rt_fixed_new:
  addi sp, sp, -16
  sw ra, 12(sp)
  sw a0, 8(sp)
  sw a1, 4(sp)
  addi t0, zero, 1
  beq a1, t0, .L_fixed_check_u8
  addi t0, zero, 2
  beq a1, t0, .L_fixed_check_u16
  j .L_fixed_allocate
.L_fixed_check_u8:
  srli t0, a0, 8
  bne t0, zero, rt_fixed_overflow_restore
  j .L_fixed_allocate
.L_fixed_check_u16:
  srli t0, a0, 16
  bne t0, zero, rt_fixed_overflow_restore
.L_fixed_allocate:
  addi a0, zero, 8
  call rt_alloc
  lw t0, 8(sp)
  sw t0, 0(a0)
  lw t0, 4(sp)
  sw t0, 4(a0)
  ori a0, a0, ${TAG.box}
  lw ra, 12(sp)
  addi sp, sp, 16
  jalr zero, 0(ra)
rt_fixed_overflow_restore:
  li a0, ${(6 << 3) | TAG.error}
  lw ra, 12(sp)
  addi sp, sp, 16
  jalr zero, 0(ra)

rt_fixed_add:
  andi t0, a0, -8
  andi t1, a1, -8
  lw t2, 0(t0)
  lw t3, 0(t1)
  lw a1, 4(t0)
  add a0, t2, t3
  addi t4, zero, 4
  beq a1, t4, .L_fixed_add_signed
  bltu a0, t2, rt_fixed_overflow
  j rt_fixed_new
.L_fixed_add_signed:
  xor t4, a0, t2
  xor t5, a0, t3
  and t4, t4, t5
  blt t4, zero, rt_fixed_overflow
  j rt_fixed_new

rt_fixed_sub:
  andi t0, a0, -8
  andi t1, a1, -8
  lw t2, 0(t0)
  lw t3, 0(t1)
  lw a1, 4(t0)
  sub a0, t2, t3
  addi t4, zero, 4
  beq a1, t4, .L_fixed_sub_signed
  bltu t2, t3, rt_fixed_overflow
  j rt_fixed_new
.L_fixed_sub_signed:
  xor t4, t2, t3
  xor t5, a0, t2
  and t4, t4, t5
  blt t4, zero, rt_fixed_overflow
  j rt_fixed_new

rt_fixed_mul:
  addi sp, sp, -16
  sw ra, 12(sp)
  andi t0, a0, -8
  andi t1, a1, -8
  lw t2, 0(t0)
  lw t3, 0(t1)
  lw t0, 4(t0)
  sw t0, 8(sp)
  addi a6, zero, 0
  addi a2, zero, 4
  bne t0, a2, .L_fixed_mul_unsigned
  bge t2, zero, .L_fixed_mul_left_ready
  sub t2, zero, t2
  xori a6, a6, 1
.L_fixed_mul_left_ready:
  bge t3, zero, .L_fixed_mul_unsigned
  sub t3, zero, t3
  xori a6, a6, 1
.L_fixed_mul_unsigned:
  addi t4, zero, 0
  addi t5, zero, 0
  addi a4, zero, 0
  addi t6, zero, 32
.L_fixed_mul_loop:
  andi a2, t3, 1
  beq a2, zero, .L_fixed_mul_shift
  add a2, t4, t2
  sltu a3, a2, t4
  add t5, t5, a4
  add t5, t5, a3
  add t4, a2, zero
.L_fixed_mul_shift:
  srli t3, t3, 1
  srli a2, t2, 31
  slli t2, t2, 1
  slli a4, a4, 1
  or a4, a4, a2
  addi t6, t6, -1
  bne t6, zero, .L_fixed_mul_loop
  bne t5, zero, .L_fixed_mul_overflow
  lw a1, 8(sp)
  addi a2, zero, 4
  bne a1, a2, .L_fixed_mul_ready
  beq a6, zero, .L_fixed_mul_positive
  li a2, 2147483648
  bltu a2, t4, .L_fixed_mul_overflow
  sub t4, zero, t4
  j .L_fixed_mul_ready
.L_fixed_mul_positive:
  li a2, 2147483647
  bltu a2, t4, .L_fixed_mul_overflow
.L_fixed_mul_ready:
  add a0, t4, zero
  call rt_fixed_new
  lw ra, 12(sp)
  addi sp, sp, 16
  jalr zero, 0(ra)
.L_fixed_mul_overflow:
  li a0, ${(6 << 3) | TAG.error}
  lw ra, 12(sp)
  addi sp, sp, 16
  jalr zero, 0(ra)

rt_fixed_div:
  andi t0, a0, -8
  andi t1, a1, -8
  lw t2, 0(t0)
  lw t3, 0(t1)
  beq t3, zero, rt_division_by_zero
  lw a1, 4(t0)
  addi a4, zero, 0
  addi a2, zero, 4
  bne a1, a2, .L_fixed_div_unsigned
  bge t2, zero, .L_fixed_div_left_ready
  sub t2, zero, t2
  xori a4, a4, 1
.L_fixed_div_left_ready:
  bge t3, zero, .L_fixed_div_unsigned
  sub t3, zero, t3
  xori a4, a4, 1
.L_fixed_div_unsigned:
  addi t4, zero, 0
  addi t5, zero, 0
  addi t6, zero, 32
.L_fixed_div_loop:
  srli a2, t2, 31
  slli t2, t2, 1
  slli t5, t5, 1
  or t5, t5, a2
  slli t4, t4, 1
  bltu t5, t3, .L_fixed_div_next
  sub t5, t5, t3
  ori t4, t4, 1
.L_fixed_div_next:
  addi t6, t6, -1
  bne t6, zero, .L_fixed_div_loop
  beq a4, zero, .L_fixed_div_positive
  sub t4, zero, t4
  j .L_fixed_div_ready
.L_fixed_div_positive:
  addi a2, zero, 4
  bne a1, a2, .L_fixed_div_ready
  blt t4, zero, rt_fixed_overflow
.L_fixed_div_ready:
  add a0, t4, zero
  j rt_fixed_new

rt_fixed_equal:
  andi t0, a0, -8
  andi t1, a1, -8
  lw t0, 0(t0)
  lw t1, 0(t1)
  beq t0, t1, .L_equal_yes
  j .L_equal_no
rt_fixed_less:
  andi t0, a0, -8
  andi t1, a1, -8
  lw t2, 4(t0)
  lw t0, 0(t0)
  lw t1, 0(t1)
  addi t3, zero, 4
  beq t2, t3, .L_fixed_less_signed
  bltu t0, t1, .L_less_yes
  j .L_equal_no
.L_fixed_less_signed:
  blt t0, t1, .L_less_yes
  j .L_equal_no
rt_fixed_greater:
  add a2, a0, zero
  add a0, a1, zero
  add a1, a2, zero
  j rt_fixed_less

rt_fixed_overflow:
  li a0, ${(6 << 3) | TAG.error}
  jalr zero, 0(ra)

rt_fixed_and:
  andi t0, a0, -8
  andi t1, a1, -8
  lw a0, 0(t0)
  lw t1, 0(t1)
  and a0, a0, t1
  addi a1, zero, 5
  j rt_fixed_new
rt_fixed_or:
  andi t0, a0, -8
  andi t1, a1, -8
  lw a0, 0(t0)
  lw t1, 0(t1)
  or a0, a0, t1
  addi a1, zero, 5
  j rt_fixed_new
rt_fixed_xor:
  andi t0, a0, -8
  andi t1, a1, -8
  lw a0, 0(t0)
  lw t1, 0(t1)
  xor a0, a0, t1
  addi a1, zero, 5
  j rt_fixed_new
rt_fixed_not:
  andi t0, a0, -8
  lw a0, 0(t0)
  xori a0, a0, -1
  addi a1, zero, 5
  j rt_fixed_new
rt_fixed_shift_left:
  andi t0, a0, -8
  andi t1, a1, -8
  lw a0, 0(t0)
  lw t1, 0(t1)
  sll a0, a0, t1
  addi a1, zero, 5
  j rt_fixed_new
rt_fixed_shift_right:
  andi t0, a0, -8
  andi t1, a1, -8
  lw a0, 0(t0)
  lw t1, 0(t1)
  srl a0, a0, t1
  addi a1, zero, 5
  j rt_fixed_new

rt_fixed_convert:
  andi t0, a0, -8
  lw t1, 4(t0)
  lw a0, 0(t0)
  addi t0, zero, 4
  bne t1, t0, .L_fixed_convert_to_signed
  blt a0, zero, rt_fixed_overflow
.L_fixed_convert_to_signed:
  bne a1, t0, .L_fixed_convert_ready
  blt a0, zero, rt_fixed_overflow
.L_fixed_convert_ready:
  j rt_fixed_new

rt_fixed_mem_load8:
  addi a2, zero, 1
  j rt_fixed_mem_load
rt_fixed_mem_load16:
  addi a2, zero, 2
  j rt_fixed_mem_load
rt_fixed_mem_load32:
  addi a2, zero, 3
rt_fixed_mem_load:
  andi t0, a0, -8
  andi t1, a1, -8
  lw t0, 0(t0)
  lw t1, 0(t1)
  add t0, t0, t1
  add a1, a2, zero
  addi t1, zero, 1
  beq a2, t1, .L_fixed_mem_load8
  addi t1, zero, 2
  beq a2, t1, .L_fixed_mem_load16
  lw a0, 0(t0)
  j rt_fixed_new
.L_fixed_mem_load8:
  lbu a0, 0(t0)
  j rt_fixed_new
.L_fixed_mem_load16:
  lhu a0, 0(t0)
  j rt_fixed_new
rt_fixed_mem_store8:
  addi t3, zero, 1
  j rt_fixed_mem_store
rt_fixed_mem_store16:
  addi t3, zero, 2
  j rt_fixed_mem_store
rt_fixed_mem_store32:
  addi t3, zero, 3
rt_fixed_mem_store:
  andi t0, a0, -8
  andi t1, a1, -8
  andi t2, a2, -8
  lw t0, 0(t0)
  lw t1, 0(t1)
  lw t2, 0(t2)
  add t0, t0, t1
  addi t1, zero, 1
  beq t3, t1, .L_fixed_mem_store8
  addi t1, zero, 2
  beq t3, t1, .L_fixed_mem_store16
  sw t2, 0(t0)
  j .L_fixed_mem_store_done
.L_fixed_mem_store8:
  sb t2, 0(t0)
  j .L_fixed_mem_store_done
.L_fixed_mem_store16:
  sh t2, 0(t0)
.L_fixed_mem_store_done:
  addi a0, zero, ${NONE}
  jalr zero, 0(ra)

rt_fixed_show:
  addi sp, sp, -64
  sw ra, 60(sp)
  andi t0, a0, -8
  lw t1, 4(t0)
  lw t0, 0(t0)
  addi t2, zero, 0
  addi t3, zero, 4
  bne t1, t3, .L_fixed_text_digits
  bge t0, zero, .L_fixed_text_digits
  addi t2, zero, 1
  sub t0, zero, t0
.L_fixed_text_digits:
  addi t3, zero, 0
.L_fixed_text_digit:
  addi t4, zero, 0
  addi t5, zero, 0
  addi t6, zero, 32
  add a3, t0, zero
.L_fixed_text_div10:
  srli a4, a3, 31
  slli a3, a3, 1
  slli t5, t5, 1
  or t5, t5, a4
  slli t4, t4, 1
  addi a4, zero, 10
  bltu t5, a4, .L_fixed_text_div10_next
  addi t5, t5, -10
  ori t4, t4, 1
.L_fixed_text_div10_next:
  addi t6, t6, -1
  bne t6, zero, .L_fixed_text_div10
  addi t5, t5, 48
  add a4, sp, t3
  sb t5, 0(a4)
  addi t3, t3, 1
  add t0, t4, zero
  bne t0, zero, .L_fixed_text_digit
  add t4, t3, t2
  sw t3, 56(sp)
  sw t2, 52(sp)
  sw t4, 48(sp)
  addi a0, t4, 5
  call rt_alloc
  lw t3, 56(sp)
  lw t2, 52(sp)
  lw t4, 48(sp)
  sw t4, 0(a0)
  addi t5, zero, 0
  beq t2, zero, .L_fixed_text_copy
  addi t6, zero, 45
  sb t6, 4(a0)
  addi t5, zero, 1
.L_fixed_text_copy:
  beq t3, zero, .L_fixed_text_done
  addi t3, t3, -1
  add t6, sp, t3
  lbu t6, 0(t6)
  add a3, a0, t5
  sb t6, 4(a3)
  addi t5, t5, 1
  j .L_fixed_text_copy
.L_fixed_text_done:
  add a3, a0, t4
  sb zero, 4(a3)
  ori a0, a0, ${TAG.string}
  call rt_show
  lw ra, 60(sp)
  addi sp, sp, 64
  jalr zero, 0(ra)

rt_add:
  add a0, a0, a1
  jalr zero, 0(ra)
rt_sub:
  sub a0, a0, a1
  jalr zero, 0(ra)
rt_mul:
  srai a0, a0, 3
  srai a1, a1, 3
  addi t0, zero, 0
  addi t1, a1, 0
  bge t1, zero, .L_mul_positive
  sub t1, zero, t1
  sub a0, zero, a0
.L_mul_positive:
  beq t1, zero, .L_mul_done
.L_mul_loop:
  andi t2, t1, 1
  beq t2, zero, .L_mul_skip
  add t0, t0, a0
.L_mul_skip:
  slli a0, a0, 1
  srli t1, t1, 1
  bne t1, zero, .L_mul_loop
.L_mul_done:
  slli a0, t0, 3
  jalr zero, 0(ra)
rt_div:
  srai a0, a0, 3
  srai a1, a1, 3
  beq a1, zero, rt_division_by_zero
  addi t0, zero, 0
  addi t1, zero, 0
  bge a0, zero, .L_div_left
  sub a0, zero, a0
  xori t1, t1, 1
.L_div_left:
  bge a1, zero, .L_div_right
  sub a1, zero, a1
  xori t1, t1, 1
.L_div_right:
  bltu a0, a1, .L_div_done
.L_div_loop:
  sub a0, a0, a1
  addi t0, t0, 1
  bgeu a0, a1, .L_div_loop
.L_div_done:
  beq t1, zero, .L_div_encode
  sub t0, zero, t0
.L_div_encode:
  slli a0, t0, 3
  jalr zero, 0(ra)

rt_equal:
  beq a0, a1, .L_equal_yes
  andi t0, a0, 7
  andi t1, a1, 7
  bne t0, t1, .L_equal_no
  addi t2, zero, ${TAG.string}
  bne t0, t2, .L_equal_no
  andi a0, a0, -8
  andi a1, a1, -8
  lw t0, 0(a0)
  lw t1, 0(a1)
  bne t0, t1, .L_equal_no
  addi t2, zero, 0
.L_equal_string:
  beq t2, t0, .L_equal_yes
  add t3, a0, t2
  add t4, a1, t2
  lbu t3, 4(t3)
  lbu t4, 4(t4)
  bne t3, t4, .L_equal_no
  addi t2, t2, 1
  j .L_equal_string
.L_equal_yes:
  addi a0, zero, ${YES}
  jalr zero, 0(ra)
.L_equal_no:
  addi a0, zero, ${NO}
  jalr zero, 0(ra)
rt_less:
  srai a0, a0, 3
  srai a1, a1, 3
  blt a0, a1, .L_less_yes
  addi a0, zero, ${NO}
  jalr zero, 0(ra)
.L_less_yes:
  addi a0, zero, ${YES}
  jalr zero, 0(ra)
rt_greater:
  srai a0, a0, 3
  srai a1, a1, 3
  blt a1, a0, .L_greater_yes
  addi a0, zero, ${NO}
  jalr zero, 0(ra)
.L_greater_yes:
  addi a0, zero, ${YES}
  jalr zero, 0(ra)

rt_box_get:
  andi a0, a0, -8
  lw t0, 0(a0)
  addi a0, a0, 4
.L_box_get_loop:
  beq t0, zero, rt_missing_field
  lw t1, 0(a0)
  beq t1, a1, .L_box_get_found
  addi a0, a0, 8
  addi t0, t0, -1
  j .L_box_get_loop
.L_box_get_found:
  lw a0, 4(a0)
  jalr zero, 0(ra)

rt_box_set:
  andi a0, a0, -8
  lw t0, 0(a0)
  addi a0, a0, 4
.L_box_set_loop:
  beq t0, zero, rt_missing_field
  lw t1, 0(a0)
  beq t1, a1, .L_box_set_found
  addi a0, a0, 8
  addi t0, t0, -1
  j .L_box_set_loop
.L_box_set_found:
  sw a2, 4(a0)
  addi a0, zero, ${NONE}
  jalr zero, 0(ra)

rt_group_count:
  andi a0, a0, -8
  lw a0, 0(a0)
  slli a0, a0, 3
  jalr zero, 0(ra)
rt_group_at:
  andi a0, a0, -8
  srai a1, a1, 3
  lw t0, 0(a0)
  bgeu a1, t0, rt_group_bounds
  slli a1, a1, 2
  add a0, a0, a1
  lw a0, 4(a0)
  jalr zero, 0(ra)
rt_group_add:
  addi sp, sp, -16
  sw ra, 12(sp)
  sw a0, 8(sp)
  sw a1, 4(sp)
  andi t0, a0, -8
  lw t1, 0(t0)
  addi a0, t1, 2
  slli a0, a0, 2
  call rt_alloc
  lw t0, 8(sp)
  andi t0, t0, -8
  lw t1, 0(t0)
  addi t2, t1, 1
  sw t2, 0(a0)
  addi t2, zero, 0
.L_group_copy:
  beq t2, t1, .L_group_copy_done
  slli t3, t2, 2
  add t4, t0, t3
  lw t5, 4(t4)
  add t4, a0, t3
  sw t5, 4(t4)
  addi t2, t2, 1
  j .L_group_copy
.L_group_copy_done:
  slli t3, t1, 2
  add t3, a0, t3
  lw t4, 4(sp)
  sw t4, 4(t3)
  ori a0, a0, ${TAG.group}
  lw ra, 12(sp)
  addi sp, sp, 16
  jalr zero, 0(ra)

rt_cstring:
  addi sp, sp, -16
  sw ra, 12(sp)
  sw a0, 8(sp)
  addi t0, a0, 0
  addi t1, zero, 0
.L_cstring_len:
  lbu t2, 0(t0)
  beq t2, zero, .L_cstring_alloc
  addi t0, t0, 1
  addi t1, t1, 1
  j .L_cstring_len
.L_cstring_alloc:
  sw t1, 4(sp)
  addi a0, t1, 5
  call rt_alloc
  lw t1, 4(sp)
  sw t1, 0(a0)
  lw t0, 8(sp)
  addi t2, zero, 0
.L_cstring_copy:
  bgtu t2, t1, .L_cstring_done
  add t3, t0, t2
  lbu t4, 0(t3)
  add t3, a0, t2
  sb t4, 4(t3)
  addi t2, t2, 1
  j .L_cstring_copy
.L_cstring_done:
  ori a0, a0, ${TAG.string}
  lw ra, 12(sp)
  addi sp, sp, 16
  jalr zero, 0(ra)

rt_string_add:
  addi sp, sp, -32
  sw ra, 28(sp)
  andi t0, a0, -8
  andi t1, a1, -8
  sw t0, 24(sp)
  sw t1, 20(sp)
  lw t2, 0(t0)
  lw t3, 0(t1)
  sw t2, 16(sp)
  sw t3, 12(sp)
  add t4, t2, t3
  sw t4, 8(sp)
  addi a0, t4, 5
  call rt_alloc
  lw t4, 8(sp)
  sw t4, 0(a0)
  addi t5, zero, 0
  lw t0, 24(sp)
  lw t1, 20(sp)
  lw t2, 16(sp)
.L_string_left:
  beq t5, t2, .L_string_right_start
  add t3, t0, t5
  lbu t4, 4(t3)
  add t3, a0, t5
  sb t4, 4(t3)
  addi t5, t5, 1
  j .L_string_left
.L_string_right_start:
  addi t6, zero, 0
  lw t2, 12(sp)
.L_string_right:
  beq t6, t2, .L_string_done
  add t3, t1, t6
  lbu t4, 4(t3)
  add t3, a0, t5
  sb t4, 4(t3)
  addi t5, t5, 1
  addi t6, t6, 1
  j .L_string_right
.L_string_done:
  add t3, a0, t5
  sb zero, 4(t3)
  ori a0, a0, ${TAG.string}
  lw ra, 28(sp)
  addi sp, sp, 32
  jalr zero, 0(ra)

rt_string_len:
  andi a0, a0, -8
  lw a0, 0(a0)
  slli a0, a0, 3
  jalr zero, 0(ra)

rt_string_at:
  addi sp, sp, -16
  sw ra, 12(sp)
  andi t0, a0, -8
  srai a1, a1, 3
  lw t1, 0(t0)
  bgeu a1, t1, rt_string_bounds
  add t0, t0, a1
  lbu t1, 4(t0)
  sw t1, 8(sp)
  addi a0, zero, 8
  call rt_alloc
  addi t0, zero, 1
  sw t0, 0(a0)
  lw t1, 8(sp)
  sb t1, 4(a0)
  sb zero, 5(a0)
  ori a0, a0, ${TAG.string}
  lw ra, 12(sp)
  addi sp, sp, 16
  jalr zero, 0(ra)

rt_string_byte:
  andi t0, a0, -8
  srai a1, a1, 3
  lw t1, 0(t0)
  bgeu a1, t1, rt_string_bounds
  add t0, t0, a1
  lbu a0, 4(t0)
  slli a0, a0, 3
  jalr zero, 0(ra)

rt_string_slice:
  addi sp, sp, -32
  sw ra, 28(sp)
  andi t0, a0, -8
  srai a1, a1, 3
  srai a2, a2, 3
  lw t1, 0(t0)
  bgtu a1, a2, rt_string_bounds
  bgtu a2, t1, rt_string_bounds
  sub t2, a2, a1
  sw t0, 24(sp)
  sw a1, 20(sp)
  sw t2, 16(sp)
  addi a0, t2, 5
  call rt_alloc
  lw t0, 24(sp)
  lw t1, 20(sp)
  lw t2, 16(sp)
  sw t2, 0(a0)
  addi t3, zero, 0
.L_slice_copy:
  beq t3, t2, .L_slice_done
  add t4, t1, t3
  add t4, t0, t4
  lbu t5, 4(t4)
  add t4, a0, t3
  sb t5, 4(t4)
  addi t3, t3, 1
  j .L_slice_copy
.L_slice_done:
  add t4, a0, t2
  sb zero, 4(t4)
  ori a0, a0, ${TAG.string}
  lw ra, 28(sp)
  addi sp, sp, 32
  jalr zero, 0(ra)

rt_string_starts_with:
  andi a0, a0, -8
  andi a1, a1, -8
  lw t0, 0(a0)
  lw t1, 0(a1)
  bgtu t1, t0, .L_string_match_no
  addi t2, zero, 0
  j .L_string_match_loop
rt_string_ends_with:
  andi a0, a0, -8
  andi a1, a1, -8
  lw t0, 0(a0)
  lw t1, 0(a1)
  bgtu t1, t0, .L_string_match_no
  sub a0, a0, zero
  sub t3, t0, t1
  add a0, a0, t3
  addi t2, zero, 0
.L_string_match_loop:
  beq t2, t1, .L_string_match_yes
  add t3, a0, t2
  add t4, a1, t2
  lbu t3, 4(t3)
  lbu t4, 4(t4)
  bne t3, t4, .L_string_match_no
  addi t2, t2, 1
  j .L_string_match_loop
.L_string_match_yes:
  addi a0, zero, ${YES}
  jalr zero, 0(ra)
.L_string_match_no:
  addi a0, zero, ${NO}
  jalr zero, 0(ra)

rt_string_contains:
  andi a0, a0, -8
  andi a1, a1, -8
  lw t0, 0(a0)
  lw t1, 0(a1)
  beq t1, zero, .L_contains_yes
  bgtu t1, t0, .L_contains_no
  sub t2, t0, t1
  addi t2, t2, 1
  addi t3, zero, 0
.L_contains_outer:
  beq t3, t2, .L_contains_no
  addi t4, zero, 0
.L_contains_inner:
  beq t4, t1, .L_contains_yes
  add t5, t3, t4
  add t5, a0, t5
  lbu t5, 4(t5)
  add t6, a1, t4
  lbu t6, 4(t6)
  bne t5, t6, .L_contains_next
  addi t4, t4, 1
  j .L_contains_inner
.L_contains_next:
  addi t3, t3, 1
  j .L_contains_outer
.L_contains_yes:
  addi a0, zero, ${YES}
  jalr zero, 0(ra)
.L_contains_no:
  addi a0, zero, ${NO}
  jalr zero, 0(ra)

rt_string_lower:
  addi a1, zero, 0
  j rt_string_case
rt_string_upper:
  addi a1, zero, 1
rt_string_case:
  addi sp, sp, -32
  sw ra, 28(sp)
  andi t0, a0, -8
  lw t1, 0(t0)
  sw t0, 24(sp)
  sw t1, 20(sp)
  sw a1, 16(sp)
  addi a0, t1, 5
  call rt_alloc
  lw t0, 24(sp)
  lw t1, 20(sp)
  lw t2, 16(sp)
  sw t1, 0(a0)
  addi t3, zero, 0
.L_case_loop:
  beq t3, t1, .L_case_done
  add t4, t0, t3
  lbu t5, 4(t4)
  beq t2, zero, .L_case_lower
  addi t4, zero, 97
  bltu t5, t4, .L_case_store
  addi t4, zero, 123
  bgeu t5, t4, .L_case_store
  addi t5, t5, -32
  j .L_case_store
.L_case_lower:
  addi t4, zero, 65
  bltu t5, t4, .L_case_store
  addi t4, zero, 91
  bgeu t5, t4, .L_case_store
  addi t5, t5, 32
.L_case_store:
  add t4, a0, t3
  sb t5, 4(t4)
  addi t3, t3, 1
  j .L_case_loop
.L_case_done:
  add t4, a0, t1
  sb zero, 4(t4)
  ori a0, a0, ${TAG.string}
  lw ra, 28(sp)
  addi sp, sp, 32
  jalr zero, 0(ra)

rt_line_count:
  andi a0, a0, -8
  lw t0, 0(a0)
  beq t0, zero, .L_line_empty
  addi t1, zero, 0
  addi t2, zero, 0
.L_line_loop:
  beq t2, t0, .L_line_done
  add t3, a0, t2
  lbu t4, 4(t3)
  addi t5, zero, 10
  bne t4, t5, .L_line_next
  addi t1, t1, 1
.L_line_next:
  addi t2, t2, 1
  j .L_line_loop
.L_line_done:
  add t3, a0, t0
  lbu t4, 3(t3)
  addi t5, zero, 10
  beq t4, t5, .L_line_encode
  addi t1, t1, 1
.L_line_encode:
  slli a0, t1, 3
  jalr zero, 0(ra)
.L_line_empty:
  addi a0, zero, 0
  jalr zero, 0(ra)

rt_number_text:
  addi sp, sp, -48
  sw ra, 44(sp)
  srai t0, a0, 3
  addi t1, zero, 0
  bge t0, zero, .L_number_abs
  addi t1, zero, 1
  sub t0, zero, t0
.L_number_abs:
  addi t2, sp, 0
  addi t3, zero, 0
  bne t0, zero, .L_number_digits
  addi t4, zero, 48
  sb t4, 0(t2)
  addi t3, zero, 1
  j .L_number_ready
.L_number_digits:
  addi t4, zero, 10
.L_number_digit_loop:
  addi t5, zero, 0
  addi t6, t0, 0
.L_number_div10:
  bltu t6, t4, .L_number_remainder
  addi t6, t6, -10
  addi t5, t5, 1
  j .L_number_div10
.L_number_remainder:
  addi t6, t6, 48
  add t4, t2, t3
  sb t6, 0(t4)
  addi t3, t3, 1
  addi t0, t5, 0
  bne t0, zero, .L_number_digits
.L_number_ready:
  beq t1, zero, .L_number_alloc
  addi t3, t3, 1
.L_number_alloc:
  sw t3, 40(sp)
  addi a0, t3, 5
  call rt_alloc
  lw t3, 40(sp)
  sw t3, 0(a0)
  addi t4, zero, 0
  beq t1, zero, .L_number_copy
  addi t5, zero, 45
  sb t5, 4(a0)
  addi t4, zero, 1
  addi t3, t3, -1
.L_number_copy:
  beq t3, zero, .L_number_done
  addi t3, t3, -1
  add t5, t2, t3
  lbu t6, 0(t5)
  add t5, a0, t4
  sb t6, 4(t5)
  addi t4, t4, 1
  j .L_number_copy
.L_number_done:
  add t5, a0, t4
  sb zero, 4(t5)
  ori a0, a0, ${TAG.string}
  lw ra, 44(sp)
  addi sp, sp, 48
  jalr zero, 0(ra)

rt_show:
  andi t0, a0, 7
  addi t1, zero, ${TAG.string}
  beq t0, t1, .L_show_string
  addi t1, zero, ${TAG.number}
  beq t0, t1, .L_show_number
  addi t1, zero, ${TAG.answer}
  beq t0, t1, .L_show_answer
  addi t1, zero, ${TAG.error}
  beq t0, t1, .L_show_error
  la a0, rt_unknown_text
  ori a0, a0, ${TAG.string}
  j .L_show_string
.L_show_number:
  addi sp, sp, -16
  sw ra, 12(sp)
  call rt_number_text
  call rt_show
  lw ra, 12(sp)
  addi sp, sp, 16
  jalr zero, 0(ra)
.L_show_answer:
  beq a0, zero, .L_show_no
  la a0, rt_yes_text
  ori a0, a0, ${TAG.string}
  j .L_show_string
.L_show_no:
  la a0, rt_no_text
  ori a0, a0, ${TAG.string}
  j .L_show_string
.L_show_error:
  srli t0, a0, 3
  addi t1, zero, 6
  bne t0, t1, .L_show_error_unknown
  la a0, rt_fixed_overflow_text
  ori a0, a0, ${TAG.string}
  j .L_show_string
.L_show_error_unknown:
  la a0, rt_unknown_text
  ori a0, a0, ${TAG.string}
  j .L_show_string
.L_show_string:
  andi t0, a0, -8
  lw a2, 0(t0)
  addi a1, t0, 4
  addi a0, zero, 1
  addi sp, sp, -16
  sw ra, 12(sp)
  call rt_platform_write
  lw ra, 12(sp)
  addi sp, sp, 16
  addi a0, zero, ${NONE}
  jalr zero, 0(ra)
rt_newline:
  addi a0, zero, 1
  la a1, rt_newline_text
  addi a2, zero, 1
  addi sp, sp, -16
  sw ra, 12(sp)
  call rt_platform_write
  lw ra, 12(sp)
  addi sp, sp, 16
  jalr zero, 0(ra)

.weak rt_platform_write
rt_platform_write:
  addi a7, zero, 64
  ecall
  jalr zero, 0(ra)

.weak rt_platform_exit
rt_platform_exit:
  addi a7, zero, 93
  ecall

rt_cpu_wait:
  wfi
  addi a0, zero, ${NONE}
  jalr zero, 0(ra)
rt_cpu_fence:
  fence rw, rw
  addi a0, zero, ${NONE}
  jalr zero, 0(ra)

rt_file_read:
  addi sp, sp, -32
  sw ra, 28(sp)
  andi t0, a0, -8
  addi a1, t0, 4
  addi a0, zero, -100
  addi a2, zero, 0
  addi a3, zero, 0
  addi a7, zero, 56
  ecall
  blt a0, zero, rt_file_error
  sw a0, 24(sp)
  li a0, 1048584
  call rt_alloc
  sw a0, 20(sp)
  lw a0, 24(sp)
  lw a1, 20(sp)
  addi a1, a1, 4
  li a2, 1048576
  addi a7, zero, 63
  ecall
  blt a0, zero, rt_file_error
  lw t0, 20(sp)
  sw a0, 0(t0)
  add t1, t0, a0
  sb zero, 4(t1)
  lw a0, 24(sp)
  addi a7, zero, 57
  ecall
  lw a0, 20(sp)
  ori a0, a0, ${TAG.string}
  lw ra, 28(sp)
  addi sp, sp, 32
  jalr zero, 0(ra)
rt_file_write:
  addi sp, sp, -32
  sw ra, 28(sp)
  sw a1, 24(sp)
  andi t0, a0, -8
  addi a1, t0, 4
  addi a0, zero, -100
  li a2, 577
  li a3, 420
  addi a7, zero, 56
  ecall
  blt a0, zero, rt_file_error
  sw a0, 20(sp)
  lw t0, 24(sp)
  andi t0, t0, -8
  lw a2, 0(t0)
  addi a1, t0, 4
  lw a0, 20(sp)
  addi a7, zero, 64
  ecall
  lw a0, 20(sp)
  addi a7, zero, 57
  ecall
  addi a0, zero, ${NONE}
  lw ra, 28(sp)
  addi sp, sp, 32
  jalr zero, 0(ra)

rt_mem_load8:
  andi t0, a0, -8
  lw t1, 4(t0)
  lw t2, 8(t0)
  srai t1, t1, 3
  srai t2, t2, 3
  slli t1, t1, 16
  slli t2, t2, 16
  srli t2, t2, 16
  srai a1, a1, 3
  or t0, t1, t2
  add t0, t0, a1
  lbu a0, 0(t0)
  slli a0, a0, 3
  jalr zero, 0(ra)
rt_mem_load16:
  andi t0, a0, -8
  lw t1, 4(t0)
  lw t2, 8(t0)
  srai t1, t1, 3
  srai t2, t2, 3
  slli t1, t1, 16
  slli t2, t2, 16
  srli t2, t2, 16
  srai a1, a1, 3
  or t0, t1, t2
  add t0, t0, a1
  lhu a0, 0(t0)
  slli a0, a0, 3
  jalr zero, 0(ra)
rt_mem_load32:
  andi t0, a0, -8
  lw t1, 4(t0)
  lw t2, 8(t0)
  srai t1, t1, 3
  srai t2, t2, 3
  slli t1, t1, 16
  slli t2, t2, 16
  srli t2, t2, 16
  srai a1, a1, 3
  or t0, t1, t2
  add t0, t0, a1
  lw a0, 0(t0)
  slli a0, a0, 3
  jalr zero, 0(ra)
rt_mem_store8:
  andi t0, a0, -8
  lw t1, 4(t0)
  lw t2, 8(t0)
  srai t1, t1, 3
  srai t2, t2, 3
  slli t1, t1, 16
  slli t2, t2, 16
  srli t2, t2, 16
  srai a1, a1, 3
  srai a2, a2, 3
  or t0, t1, t2
  add t0, t0, a1
  sb a2, 0(t0)
  addi a0, zero, 2
  jalr zero, 0(ra)
rt_mem_store16:
  andi t0, a0, -8
  lw t1, 4(t0)
  lw t2, 8(t0)
  srai t1, t1, 3
  srai t2, t2, 3
  slli t1, t1, 16
  slli t2, t2, 16
  srli t2, t2, 16
  srai a1, a1, 3
  srai a2, a2, 3
  or t0, t1, t2
  add t0, t0, a1
  sh a2, 0(t0)
  addi a0, zero, 2
  jalr zero, 0(ra)
rt_mem_store32:
  andi t0, a0, -8
  lw t1, 4(t0)
  lw t2, 8(t0)
  srai t1, t1, 3
  srai t2, t2, 3
  slli t1, t1, 16
  slli t2, t2, 16
  srli t2, t2, 16
  srai a1, a1, 3
  srai a2, a2, 3
  or t0, t1, t2
  add t0, t0, a1
  sw a2, 0(t0)
  addi a0, zero, 2
  jalr zero, 0(ra)
rt_mem_store_address32:
  andi t0, a0, -8
  lw t1, 4(t0)
  lw t2, 8(t0)
  srai t1, t1, 3
  srai t2, t2, 3
  slli t1, t1, 16
  slli t2, t2, 16
  srli t2, t2, 16
  or t0, t1, t2
  srai a1, a1, 3
  add t0, t0, a1
  andi t3, a2, -8
  lw t1, 4(t3)
  lw t2, 8(t3)
  srai t1, t1, 3
  srai t2, t2, 3
  slli t1, t1, 16
  slli t2, t2, 16
  srli t2, t2, 16
  or t3, t1, t2
  sw t3, 0(t0)
  addi a0, zero, 2
  jalr zero, 0(ra)

rt_missing_args:
  addi a0, zero, 64
  j rt_platform_exit
rt_out_of_memory:
  addi a0, zero, 65
  j rt_platform_exit
rt_missing_field:
  li a0, ${(1 << 3) | TAG.error}
  jalr zero, 0(ra)
rt_group_bounds:
  li a0, ${(2 << 3) | TAG.error}
  jalr zero, 0(ra)
rt_string_bounds:
  li a0, ${(5 << 3) | TAG.error}
  jalr zero, 0(ra)
rt_division_by_zero:
  li a0, ${(3 << 3) | TAG.error}
  jalr zero, 0(ra)
rt_file_error:
  li a0, ${(4 << 3) | TAG.error}
  lw ra, 28(sp)
  addi sp, sp, 32
  jalr zero, 0(ra)

.section .rodata
.balign 8
rt_unknown_text:
  .word 7
  .ascii "<value>"
  .byte 0
  .balign 8
rt_fixed_overflow_text:
  .word 89
  .ascii "значение вышло за границы фиксированного целого"
  .byte 0
  .balign 8
rt_yes_text:
  .word 3
  .ascii "yes"
  .byte 0
  .balign 8
rt_no_text:
  .word 2
  .ascii "no"
  .byte 0
  .balign 8
rt_newline_text:
  .byte 10
`
}

function compileFile(source, output, options = {}) {
  const ast = parser.loadFile(source, { expandCore: false })
  const diagnostics = checker.checkDatum(parser.astWithLocations(ast))
  if (diagnostics.length) throw new Error(diagnostics.map(checker.diagnosticText).join('\n'))
  const assembly = new Compiler(ast).compile()
  if (options.assembly) fs.writeFileSync(options.assembly, assembly)
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'saltic-compiler-'))
  const input = path.join(folder, 'program.s')
  fs.writeFileSync(input, assembly)
  const command = options.gcc || 'riscv32-none-elf-gcc'
  const args = ['-march=rv32i', '-mabi=ilp32', '-mno-relax', '-nostdlib', '-Wl,--no-relax,-Ttext=0x10000,-e,_start', input, '-o', output]
  const result = child.spawnSync(command, args, { encoding: 'utf8' })
  fs.rmSync(folder, { recursive: true, force: true })
  if (result.error) throw new Error(`compile: cannot run ${command}: ${result.error.message}`)
  if (result.status !== 0) throw new Error(result.stderr.trim() || `${command} failed with status ${result.status}`)
  return { output, assembly }
}

module.exports = { Compiler, compileFile }

if (require.main === module) {
  const args = process.argv.slice(2)
  let assembly = null
  if (args[0] === '--assembly') assembly = args.shift() && args.shift()
  if (args.length !== 2) {
    console.error('usage: node js/3-compiler.js [--assembly output.s] <input.saltic> <output.elf>')
    process.exit(2)
  }
  try {
    compileFile(args[0], args[1], { assembly })
  } catch (error) {
    console.error(error.message)
    process.exit(1)
  }
}
