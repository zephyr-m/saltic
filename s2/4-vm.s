use core

VM_PAGE_SIZE = 256
VM_WORD_BASE = 256
VM_HEX = "0123456789abcdef"
VM_PRINTABLE = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"

VmWord = Box {
    b0 = 0
    b1 = 0
    b2 = 0
    b3 = 0
}

VmByte = Box {
    value = 0
}

VmPage = Box {
    index = 0
    present = no
    cells = []
}

VmMemory = Box {
    size = 0
    pages = []
}

VmFile = Box {
    path = ""
    data = []
}

VmName = Box {
    text = ""
    data = []
    present = no
}

VmHandle = Box {
    guest_fd = 0
    file_index = 0
    position = 0
    readable = no
    writable = no
    append = no
    open = no
}

VmOptions = Box {
    load_address = 4096
    memory_size = 262144
    step_limit = 100000
    program_name = "program"
    arguments = []
    files = []
}

VmResult = Box {
    exit_code = 0
    reason = ""
    pc = "00000000"
    steps = 0
    registers = []
    stdout = []
    stderr = []
    files = []
    trap = ""
}

VmMachine = Box {
    memory = VmMemory {}
    registers = []
    pc = 0
    halted = no
    halt_reason = ""
    exit_code = 0
    steps = 0
    trap = ""
    stdout = []
    stderr = []
    files = []
    names = []
    handles = []
    next_fd = 3
}

VmInstruction = Box {
    word = VmWord {}
    opcode = 0
    rd = 0
    funct3 = 0
    rs1 = 0
    rs2 = 0
    funct7 = 0
}

VmControl = Box {
    next_pc = 0
    handled = no
}

skill vm_mod(value, divisor) {
    out value - value / divisor * divisor
}

skill vm_word_bytes(b0, b1, b2, b3) {
    out VmWord { b0 = b0 b1 = b1 b2 = b2 b3 = b3 }
}

skill vm_word_zero() {
    out VmWord {}
}

skill vm_word_copy(word) {
    out vm_word_bytes(word.b0, word.b1, word.b2, word.b3)
}

skill vm_byte_and(left, right) {
    @a = left
    @b = right
    @weight = 1
    @result = 0
    drum (8) {
        @a_bit = vm_mod(a, 2)
        @b_bit = vm_mod(b, 2)
        (a_bit == 1) {
            (b_bit == 1) { result = result + weight }
        }
        a = a / 2
        b = b / 2
        weight = weight * 2
    }
    out result
}

skill vm_byte_or(left, right) {
    @a = left
    @b = right
    @weight = 1
    @result = 0
    drum (8) {
        @bits = vm_mod(a, 2) + vm_mod(b, 2)
        (bits > 0) { result = result + weight }
        a = a / 2
        b = b / 2
        weight = weight * 2
    }
    out result
}

skill vm_byte_xor(left, right) {
    @a = left
    @b = right
    @weight = 1
    @result = 0
    drum (8) {
        @bits = vm_mod(a, 2) + vm_mod(b, 2)
        (bits == 1) { result = result + weight }
        a = a / 2
        b = b / 2
        weight = weight * 2
    }
    out result
}

skill vm_word_not(word) {
    out vm_word_bytes(255 - word.b0, 255 - word.b1, 255 - word.b2, 255 - word.b3)
}

skill vm_word_add(left, right) {
    @v0 = left.b0 + right.b0
    @c0 = v0 / 256
    @v1 = left.b1 + right.b1 + c0
    @c1 = v1 / 256
    @v2 = left.b2 + right.b2 + c1
    @c2 = v2 / 256
    @v3 = left.b3 + right.b3 + c2
    out vm_word_bytes(vm_mod(v0, 256), vm_mod(v1, 256), vm_mod(v2, 256), vm_mod(v3, 256))
}

skill vm_word_negate(word) {
    out vm_word_add(vm_word_not(word), vm_word_bytes(1, 0, 0, 0))
}

skill vm_word_number(value) {
    @negative = no
    @current = value
    (current < 0) { negative = yes current = 0 - current }
    @b0 = vm_mod(current, 256)
    current = current / 256
    @b1 = vm_mod(current, 256)
    current = current / 256
    @b2 = vm_mod(current, 256)
    current = current / 256
    @b3 = vm_mod(current, 256)
    @word = vm_word_bytes(b0, b1, b2, b3)
    (negative == yes) { out vm_word_negate(word) }
    out word
}

skill vm_word_sub(left, right) {
    out vm_word_add(left, vm_word_negate(right))
}

skill vm_word_and(left, right) {
    out vm_word_bytes(vm_byte_and(left.b0, right.b0), vm_byte_and(left.b1, right.b1), vm_byte_and(left.b2, right.b2), vm_byte_and(left.b3, right.b3))
}

skill vm_word_or(left, right) {
    out vm_word_bytes(vm_byte_or(left.b0, right.b0), vm_byte_or(left.b1, right.b1), vm_byte_or(left.b2, right.b2), vm_byte_or(left.b3, right.b3))
}

skill vm_word_xor(left, right) {
    out vm_word_bytes(vm_byte_xor(left.b0, right.b0), vm_byte_xor(left.b1, right.b1), vm_byte_xor(left.b2, right.b2), vm_byte_xor(left.b3, right.b3))
}

skill vm_word_shift_left_one(word) {
    @c0 = word.b0 / 128
    @c1 = word.b1 / 128
    @c2 = word.b2 / 128
    out vm_word_bytes(vm_mod(word.b0 * 2, 256), vm_mod(word.b1 * 2 + c0, 256), vm_mod(word.b2 * 2 + c1, 256), vm_mod(word.b3 * 2 + c2, 256))
}

skill vm_word_shift_right_one(word) {
    out vm_word_bytes(word.b0 / 2 + vm_mod(word.b1, 2) * 128, word.b1 / 2 + vm_mod(word.b2, 2) * 128, word.b2 / 2 + vm_mod(word.b3, 2) * 128, word.b3 / 2)
}

skill vm_word_shift_right_arithmetic_one(word) {
    @high = word.b3 / 2
    (word.b3 > 127) { high = high + 128 }
    out vm_word_bytes(word.b0 / 2 + vm_mod(word.b1, 2) * 128, word.b1 / 2 + vm_mod(word.b2, 2) * 128, word.b2 / 2 + vm_mod(word.b3, 2) * 128, high)
}

skill vm_word_shift_left(word, amount) {
    @result = vm_word_copy(word)
    drum (amount) { result = vm_word_shift_left_one(result) }
    out result
}

skill vm_word_shift_right(word, amount) {
    @result = vm_word_copy(word)
    drum (amount) { result = vm_word_shift_right_one(result) }
    out result
}

skill vm_word_shift_right_arithmetic(word, amount) {
    @result = vm_word_copy(word)
    drum (amount) { result = vm_word_shift_right_arithmetic_one(result) }
    out result
}

skill vm_word_multiply(left, right) {
    @result = vm_word_zero()
    @addend = vm_word_copy(left)
    @multiplier = vm_word_copy(right)
    drum (32) {
        (vm_mod(multiplier.b0, 2) == 1) { result = vm_word_add(result, addend) }
        addend = vm_word_shift_left_one(addend)
        multiplier = vm_word_shift_right_one(multiplier)
    }
    out result
}

skill vm_word_equal(left, right) {
    (left.b0 == right.b0) {
        (left.b1 == right.b1) {
            (left.b2 == right.b2) {
                (left.b3 == right.b3) { out yes }
            }
        }
    }
    out no
}

skill vm_word_unsigned_less(left, right) {
    (left.b3 < right.b3) { out yes }
    (left.b3 > right.b3) { out no }
    (left.b2 < right.b2) { out yes }
    (left.b2 > right.b2) { out no }
    (left.b1 < right.b1) { out yes }
    (left.b1 > right.b1) { out no }
    out left.b0 < right.b0
}

skill vm_word_signed_less(left, right) {
    @left_negative = left.b3 > 127
    @right_negative = right.b3 > 127
    (left_negative == yes) {
        (right_negative == no) { out yes }
    }
    (left_negative == no) {
        (right_negative == yes) { out no }
    }
    out vm_word_unsigned_less(left, right)
}

skill vm_word_address(word) {
    (word.b3 > 15) { out 0 - 1 }
    out word.b0 + word.b1 * 256 + word.b2 * 65536 + word.b3 * 16777216
}

skill vm_word_signed_number(word) {
    (word.b3 < 128) { out vm_word_address(word) }
    @magnitude = vm_word_address(vm_word_negate(word))
    out 0 - magnitude
}

skill vm_word_hex(word) {
    @text = core.str.at(VM_HEX, word.b3 / 16)
    text = core.str.add(text, core.str.at(VM_HEX, vm_mod(word.b3, 16)))
    text = core.str.add(text, core.str.at(VM_HEX, word.b2 / 16))
    text = core.str.add(text, core.str.at(VM_HEX, vm_mod(word.b2, 16)))
    text = core.str.add(text, core.str.at(VM_HEX, word.b1 / 16))
    text = core.str.add(text, core.str.at(VM_HEX, vm_mod(word.b1, 16)))
    text = core.str.add(text, core.str.at(VM_HEX, word.b0 / 16))
    out core.str.add(text, core.str.at(VM_HEX, vm_mod(word.b0, 16)))
}

skill vm_number_hex(value) {
    out vm_word_hex(vm_word_number(value))
}

skill vm_memory_page(memory, page_index, create) {
    @index = 0
    @count = core.group.count(memory.pages)
    drum (count) {
        @page = core.group.at(memory.pages, index)
        (page.index == page_index) { out page }
        index = index + 1
    }
    (create == yes) {
        @cells = []
        @cell_index = 0
        drum (VM_PAGE_SIZE) {
            cells = core.group.add(cells, VmByte {})
            cell_index = cell_index + 1
        }
        @page = VmPage { index = page_index present = yes cells = cells }
        memory.pages = core.group.add(memory.pages, page)
        out page
    }
    out VmPage {}
}

skill vm_memory_raw_load8(memory, address) {
    @page = vm_memory_page(memory, address / VM_PAGE_SIZE, no)
    (page.present == no) { out 0 }
    @cell = core.group.at(page.cells, vm_mod(address, VM_PAGE_SIZE))
    out cell.value
}

skill vm_memory_raw_store8(memory, address, value) {
    @page = vm_memory_page(memory, address / VM_PAGE_SIZE, yes)
    @cell = core.group.at(page.cells, vm_mod(address, VM_PAGE_SIZE))
    cell.value = vm_mod(value, 256)
    out none
}

skill vm_trap(machine, reason, detail) {
    @message = core.str.add(reason, " at 0x")
    message = core.str.add(message, vm_number_hex(machine.pc))
    (core.str.len(detail) > 0) {
        message = core.str.add(message, ": ")
        message = core.str.add(message, detail)
    }
    machine.trap = message
    machine.halted = yes
    out none
}

skill vm_memory_check(machine, address, size, alignment, access) {
    @valid = yes
    (address < 0) { valid = no }
    (address > machine.memory.size - size) { valid = no }
    (valid == no) {
        @detail = core.str.add("memory access 0x", vm_number_hex(address))
        detail = core.str.add(detail, "..0x")
        detail = core.str.add(detail, vm_number_hex(address + size - 1))
        detail = core.str.add(detail, " is outside RAM")
        vm_trap(machine, core.str.add(access, " access fault"), detail)
        out no
    }
    (vm_mod(address, alignment) > 0) {
        @detail = core.str.add("misaligned ", core.num.text(alignment))
        detail = core.str.add(detail, "-byte access at 0x")
        detail = core.str.add(detail, vm_number_hex(address))
        vm_trap(machine, core.str.add(access, " access fault"), detail)
        out no
    }
    out yes
}

skill vm_memory_load_word(memory, address) {
    out vm_word_bytes(vm_memory_raw_load8(memory, address), vm_memory_raw_load8(memory, address + 1), vm_memory_raw_load8(memory, address + 2), vm_memory_raw_load8(memory, address + 3))
}

skill vm_memory_store_word(memory, address, word, size) {
    vm_memory_raw_store8(memory, address, word.b0)
    (size > 1) { vm_memory_raw_store8(memory, address + 1, word.b1) }
    (size > 2) {
        vm_memory_raw_store8(memory, address + 2, word.b2)
        vm_memory_raw_store8(memory, address + 3, word.b3)
    }
    out none
}

skill vm_register(machine, index) {
    (index == 0) { out vm_word_zero() }
    out core.group.at(machine.registers, index)
}

skill vm_set_register(machine, index, word) {
    (index > 0) {
        @target = core.group.at(machine.registers, index)
        target.b0 = word.b0
        target.b1 = word.b1
        target.b2 = word.b2
        target.b3 = word.b3
    }
    out none
}

skill vm_ascii_code(ch) {
    (ch == "\n") { out 10 }
    (ch == "\t") { out 9 }
    @index = 0
    @length = core.str.len(VM_PRINTABLE)
    drum (length) {
        (core.str.at(VM_PRINTABLE, index) == ch) { out index + 32 }
        index = index + 1
    }
    out 0
}

skill vm_text_bytes(text) {
    @bytes = []
    @index = 0
    @length = core.str.len(text)
    drum (length) {
        bytes = core.group.add(bytes, vm_ascii_code(core.str.at(text, index)))
        index = index + 1
    }
    out bytes
}

skill vm_name_add(machine, text) {
    @index = 0
    @count = core.group.count(machine.names)
    drum (count) {
        @name = core.group.at(machine.names, index)
        (name.text == text) { out name.data }
        index = index + 1
    }
    @data = vm_text_bytes(text)
    machine.names = core.group.add(machine.names, VmName { text = text data = data present = yes })
    out data
}

skill vm_new_machine(options) {
    @registers = []
    @index = 0
    drum (32) {
        registers = core.group.add(registers, vm_word_zero())
        index = index + 1
    }
    @machine = VmMachine {
        memory = VmMemory { size = options.memory_size pages = [] }
        registers = registers
        files = options.files
    }
    vm_name_add(machine, options.program_name)
    index = 0
    @argument_count = core.group.count(options.arguments)
    drum (argument_count) {
        vm_name_add(machine, core.group.at(options.arguments, index))
        index = index + 1
    }
    index = 0
    @file_count = core.group.count(options.files)
    drum (file_count) {
        @file = core.group.at(options.files, index)
        vm_name_add(machine, file.path)
        index = index + 1
    }
    out machine
}

skill vm_image_u16(image, offset) {
    out vm_image_byte(image, offset) + vm_image_byte(image, offset + 1) * 256
}

skill vm_image_u32(image, offset) {
    @word = vm_word_bytes(vm_image_byte(image, offset), vm_image_byte(image, offset + 1), vm_image_byte(image, offset + 2), vm_image_byte(image, offset + 3))
    out vm_word_address(word)
}

skill vm_image_length(image) {
    @length = 0
    @index = 0
    @count = core.group.count(image)
    drum (count) {
        @chunk = core.group.at(image, index)
        length = length + core.group.count(chunk)
        index = index + 1
    }
    out length
}

skill vm_image_byte(image, offset) {
    @chunk = core.group.at(image, offset / VM_PAGE_SIZE)
    out core.group.at(chunk, vm_mod(offset, VM_PAGE_SIZE))
}

skill vm_load_error(machine, message) {
    machine.trap = message
    machine.halted = yes
    out none
}

skill vm_copy_image(machine, image, offset, address, size) {
    @index = 0
    drum (size) {
        vm_memory_raw_store8(machine.memory, address + index, vm_image_byte(image, offset + index))
        index = index + 1
    }
    out none
}

skill vm_fill_memory(machine, address, size) {
    @index = 0
    drum (size) {
        vm_memory_raw_store8(machine.memory, address + index, 0)
        index = index + 1
    }
    out none
}

skill vm_load_flat(machine, image, address) {
    @size = vm_image_length(image)
    (address < 0) { vm_load_error(machine, "flat image address is outside RAM") out none }
    (address > machine.memory.size - size) { vm_load_error(machine, "flat image is outside RAM") out none }
    vm_copy_image(machine, image, 0, address, size)
    machine.pc = address
    out none
}

skill vm_load_elf(machine, image) {
    @length = vm_image_length(image)
    (length < 52) { vm_load_error(machine, "ELF header is truncated") out none }
    (vm_image_byte(image, 4) == 1) {
        (vm_image_byte(image, 5) == 1) {
            (vm_image_u16(image, 18) == 243) {
                @entry = vm_image_u32(image, 24)
                @table = vm_image_u32(image, 28)
                @entry_size = vm_image_u16(image, 42)
                @count = vm_image_u16(image, 44)
                @segments = 0
                @index = 0
                drum (count) {
                    (core.str.len(machine.trap) == 0) {
                        @header = table + index * entry_size
                        (header > length - 32) {
                            vm_load_error(machine, "ELF program header is truncated")
                        }
                        (header < length - 31) {
                            (vm_image_u32(image, header) == 1) {
                                @offset = vm_image_u32(image, header + 4)
                                @address = vm_image_u32(image, header + 8)
                                @file_size = vm_image_u32(image, header + 16)
                                @memory_size = vm_image_u32(image, header + 20)
                                @valid = yes
                                (file_size > memory_size) { valid = no }
                                (offset > length - file_size) { valid = no }
                                (address < 0) { valid = no }
                                (address > machine.memory.size - memory_size) { valid = no }
                                (valid == no) { vm_load_error(machine, "invalid ELF load segment") }
                                (valid == yes) {
                                    vm_copy_image(machine, image, offset, address, file_size)
                                    (memory_size > file_size) { vm_fill_memory(machine, address + file_size, memory_size - file_size) }
                                    segments = segments + 1
                                }
                            }
                        }
                    }
                    index = index + 1
                }
                (core.str.len(machine.trap) == 0) {
                    (segments == 0) { vm_load_error(machine, "ELF contains no loadable segments") }
                    (segments > 0) { machine.pc = entry }
                }
                out none
            }
            vm_load_error(machine, "ELF machine is not RISC-V")
            out none
        }
        vm_load_error(machine, "only little-endian ELF is supported")
        out none
    }
    vm_load_error(machine, "only ELF32 is supported")
    out none
}

skill vm_load(machine, image, address) {
    @elf = no
    (vm_image_length(image) > 3) {
        (vm_image_byte(image, 0) == 127) {
            (vm_image_byte(image, 1) == 69) {
                (vm_image_byte(image, 2) == 76) {
                    (vm_image_byte(image, 3) == 70) { elf = yes }
                }
            }
        }
    }
    (elf == yes) { vm_load_elf(machine, image) out none }
    vm_load_flat(machine, image, address)
    out none
}

skill vm_prepare_stack(machine, options) {
    @values = core.group.add([], options.program_name)
    @index = 0
    @argument_count = core.group.count(options.arguments)
    drum (argument_count) {
        values = core.group.add(values, core.group.at(options.arguments, index))
        index = index + 1
    }

    @count = core.group.count(values)
    @cursor = machine.memory.size - 16
    cursor = cursor - vm_mod(cursor, 16)
    @addresses = []
    index = count
    drum (count) {
        index = index - 1
        @data = vm_name_add(machine, core.group.at(values, index))
        cursor = cursor - core.group.count(data) - 1
        @byte_index = 0
        @byte_count = core.group.count(data)
        drum (byte_count) {
            vm_memory_raw_store8(machine.memory, cursor + byte_index, core.group.at(data, byte_index))
            byte_index = byte_index + 1
        }
        vm_memory_raw_store8(machine.memory, cursor + byte_count, 0)
        addresses = core.group.add(addresses, cursor)
    }

    @stack = cursor - (count + 2) * 4
    stack = stack - vm_mod(stack, 16)
    @argv = stack + 4
    vm_memory_store_word(machine.memory, stack, vm_word_number(count), 4)
    index = 0
    drum (count) {
        @reverse_index = count - index - 1
        vm_memory_store_word(machine.memory, argv + reverse_index * 4, vm_word_number(core.group.at(addresses, index)), 4)
        index = index + 1
    }
    vm_memory_store_word(machine.memory, argv + count * 4, vm_word_zero(), 4)
    vm_set_register(machine, 2, vm_word_number(stack))
    vm_set_register(machine, 10, vm_word_number(count))
    vm_set_register(machine, 11, vm_word_number(argv))
    out none
}

skill vm_word_small(word) {
    (word.b3 > 15) { out 0 - 1 }
    out vm_word_address(word)
}

skill vm_flag(value, flag) {
    out vm_mod(value / flag, 2) == 1
}

skill vm_memory_matches(machine, address, data) {
    @count = core.group.count(data)
    (address < 0) { out no }
    (address > machine.memory.size - count - 1) { out no }
    @same = yes
    @index = 0
    drum (count) {
        @memory_byte = vm_memory_raw_load8(machine.memory, address + index)
        @data_byte = core.group.at(data, index)
        (memory_byte < data_byte) { same = no }
        (memory_byte > data_byte) { same = no }
        index = index + 1
    }
    (vm_memory_raw_load8(machine.memory, address + count) > 0) { same = no }
    out same
}

skill vm_memory_name(machine, address) {
    @index = 0
    @count = core.group.count(machine.names)
    drum (count) {
        @name = core.group.at(machine.names, index)
        (vm_memory_matches(machine, address, name.data) == yes) { out name }
        index = index + 1
    }
    out VmName {}
}

skill vm_file_index(machine, path) {
    @found = 0 - 1
    @index = 0
    @count = core.group.count(machine.files)
    drum (count) {
        @file = core.group.at(machine.files, index)
        (file.path == path) { found = index }
        index = index + 1
    }
    out found
}

skill vm_handle(machine, guest_fd) {
    @index = 0
    @count = core.group.count(machine.handles)
    drum (count) {
        @handle = core.group.at(machine.handles, index)
        (handle.guest_fd == guest_fd) {
            (handle.open == yes) { out handle }
        }
        index = index + 1
    }
    out VmHandle {}
}

skill vm_file_set(file, position, value) {
    @count = core.group.count(file.data)
    (position < count) {
        @next = []
        @index = 0
        drum (count) {
            @item = core.group.at(file.data, index)
            (index == position) { item = value }
            next = core.group.add(next, item)
            index = index + 1
        }
        file.data = next
        out none
    }
    @cursor = count
    drum (position - count) {
        file.data = core.group.add(file.data, 0)
        cursor = cursor + 1
    }
    file.data = core.group.add(file.data, value)
    out none
}

skill vm_syscall_open(machine) {
    @address = vm_word_small(vm_register(machine, 11))
    @flags = vm_word_small(vm_register(machine, 12))
    @name = vm_memory_name(machine, address)
    (name.present == no) { out vm_word_number(0 - 1) }

    @access = vm_mod(flags, 4)
    @readable = access == 0
    @writable = access > 0
    @create = vm_flag(flags, 64)
    @exclusive = vm_flag(flags, 128)
    @truncate = vm_flag(flags, 512)
    @append = vm_flag(flags, 1024)
    @file_index = vm_file_index(machine, name.text)
    @existed = file_index > 0 - 1

    (file_index < 0) {
        (create == no) { out vm_word_number(0 - 1) }
        machine.files = core.group.add(machine.files, VmFile { path = name.text data = [] })
        file_index = core.group.count(machine.files) - 1
    }
    (existed == yes) {
        (create == yes) {
            (exclusive == yes) { out vm_word_number(0 - 1) }
        }
    }

    @file = core.group.at(machine.files, file_index)
    (truncate == yes) { file.data = [] }
    @position = 0
    (append == yes) { position = core.group.count(file.data) }
    @fd = machine.next_fd
    machine.next_fd = machine.next_fd + 1
    machine.handles = core.group.add(machine.handles, VmHandle {
        guest_fd = fd
        file_index = file_index
        position = position
        readable = readable
        writable = writable
        append = append
        open = yes
    })
    out vm_word_number(fd)
}

skill vm_syscall_close(machine) {
    @fd = vm_word_small(vm_register(machine, 10))
    @handle = vm_handle(machine, fd)
    (handle.open == no) { out vm_word_number(0 - 1) }
    handle.open = no
    out vm_word_zero()
}

skill vm_syscall_seek(machine) {
    @fd = vm_word_small(vm_register(machine, 10))
    @offset = vm_word_signed_number(vm_register(machine, 11))
    @whence = vm_word_small(vm_register(machine, 12))
    @handle = vm_handle(machine, fd)
    (handle.open == no) { out vm_word_number(0 - 1) }
    @position = handle.position
    (whence == 0) { position = offset }
    (whence == 1) { position = position + offset }
    (whence == 2) {
        @file = core.group.at(machine.files, handle.file_index)
        position = core.group.count(file.data) + offset
    }
    (whence < 0) { out vm_word_number(0 - 1) }
    (whence > 2) { out vm_word_number(0 - 1) }
    (position < 0) { out vm_word_number(0 - 1) }
    handle.position = position
    out vm_word_number(position)
}

skill vm_syscall_read(machine) {
    @fd = vm_word_small(vm_register(machine, 10))
    @address = vm_word_small(vm_register(machine, 11))
    @requested = vm_word_small(vm_register(machine, 12))
    @handle = vm_handle(machine, fd)
    (handle.open == no) { out vm_word_number(0 - 1) }
    (handle.readable == no) { out vm_word_number(0 - 1) }
    (address < 0) { out vm_word_number(0 - 1) }
    (address > machine.memory.size - requested) { out vm_word_number(0 - 1) }
    @file = core.group.at(machine.files, handle.file_index)
    @available = core.group.count(file.data) - handle.position
    @count = requested
    (count > available) { count = available }
    @index = 0
    drum (count) {
        vm_memory_raw_store8(machine.memory, address + index, core.group.at(file.data, handle.position + index))
        index = index + 1
    }
    handle.position = handle.position + count
    out vm_word_number(count)
}

skill vm_syscall_write_file(machine, handle, address, count) {
    @file = core.group.at(machine.files, handle.file_index)
    @index = 0
    drum (count) {
        vm_file_set(file, handle.position + index, vm_memory_raw_load8(machine.memory, address + index))
        index = index + 1
    }
    handle.position = handle.position + count
    out vm_word_number(count)
}

skill vm_syscall_write(machine) {
    @fd = vm_word_small(vm_register(machine, 10))
    @address = vm_word_small(vm_register(machine, 11))
    @count = vm_word_small(vm_register(machine, 12))
    (address < 0) { out vm_word_number(0 - 1) }
    (address > machine.memory.size - count) { out vm_word_number(0 - 1) }
    (fd == 1) {
        @index = 0
        drum (count) {
            machine.stdout = core.group.add(machine.stdout, vm_memory_raw_load8(machine.memory, address + index))
            index = index + 1
        }
        out vm_word_number(count)
    }
    (fd == 2) {
        @index = 0
        drum (count) {
            machine.stderr = core.group.add(machine.stderr, vm_memory_raw_load8(machine.memory, address + index))
            index = index + 1
        }
        out vm_word_number(count)
    }
    @handle = vm_handle(machine, fd)
    (handle.open == no) { out vm_word_number(0 - 1) }
    (handle.writable == no) { out vm_word_number(0 - 1) }
    out vm_syscall_write_file(machine, handle, address, count)
}

skill vm_ecall(machine) {
    @number = vm_word_small(vm_register(machine, 17))
    (number == 56) { vm_set_register(machine, 10, vm_syscall_open(machine)) out none }
    (number == 57) { vm_set_register(machine, 10, vm_syscall_close(machine)) out none }
    (number == 62) { vm_set_register(machine, 10, vm_syscall_seek(machine)) out none }
    (number == 63) { vm_set_register(machine, 10, vm_syscall_read(machine)) out none }
    (number == 64) { vm_set_register(machine, 10, vm_syscall_write(machine)) out none }
    (number == 93) {
        @code = vm_register(machine, 10)
        machine.exit_code = code.b0
        machine.halted = yes
        machine.halt_reason = "exit"
        vm_set_register(machine, 10, vm_word_zero())
        out none
    }
    (number == 94) {
        @code = vm_register(machine, 10)
        machine.exit_code = code.b0
        machine.halted = yes
        machine.halt_reason = "exit"
        vm_set_register(machine, 10, vm_word_zero())
        out none
    }
    vm_trap(machine, "unsupported ecall", core.str.add("number ", core.num.text(number)))
    out none
}

skill vm_decode(word) {
    @opcode = vm_mod(word.b0, 128)
    @rd = word.b0 / 128 + vm_mod(word.b1, 16) * 2
    @funct3 = vm_mod(word.b1 / 16, 8)
    @rs1 = word.b1 / 128 + vm_mod(word.b2, 16) * 2
    @rs2 = word.b2 / 16 + vm_mod(word.b3, 2) * 16
    @funct7 = word.b3 / 2
    out VmInstruction { word = word opcode = opcode rd = rd funct3 = funct3 rs1 = rs1 rs2 = rs2 funct7 = funct7 }
}

skill vm_immediate_i(instruction) {
    @value = instruction.word.b2 / 16 + instruction.word.b3 * 16
    (value > 2047) { value = value - 4096 }
    out value
}

skill vm_immediate_s(instruction) {
    @low = instruction.rd
    @value = low + instruction.funct7 * 32
    (value > 2047) { value = value - 4096 }
    out value
}

skill vm_immediate_b(instruction) {
    @bit12 = instruction.word.b3 / 128
    @bit11 = instruction.word.b0 / 128
    @bits10_5 = vm_mod(instruction.word.b3 / 2, 64)
    @bits4_1 = vm_mod(instruction.word.b1, 16)
    @value = bit12 * 4096 + bit11 * 2048 + bits10_5 * 32 + bits4_1 * 2
    (value > 4095) { value = value - 8192 }
    out value
}

skill vm_immediate_j(instruction) {
    @bit20 = instruction.word.b3 / 128
    @bit11 = vm_mod(instruction.word.b2 / 16, 2)
    @bits19_12 = instruction.word.b1 / 16 + vm_mod(instruction.word.b2, 16) * 16
    @bits10_1 = instruction.word.b2 / 32 + vm_mod(instruction.word.b3, 128) * 8
    @value = bit20 * 1048576 + bits19_12 * 4096 + bit11 * 2048 + bits10_1 * 2
    (value > 1048575) { value = value - 2097152 }
    out value
}

skill vm_immediate_u(instruction) {
    out vm_word_bytes(0, instruction.word.b1 / 16 * 16, instruction.word.b2, instruction.word.b3)
}

skill vm_boolean_word(value) {
    (value == yes) { out vm_word_number(1) }
    out vm_word_zero()
}

skill vm_illegal(machine, instruction) {
    vm_trap(machine, "illegal instruction", core.str.add("0x", vm_word_hex(instruction.word)))
    out none
}

skill vm_effective_address(machine, register_index, immediate) {
    out vm_word_add(vm_register(machine, register_index), vm_word_number(immediate))
}

skill vm_execute_lui(machine, instruction, control) {
    vm_set_register(machine, instruction.rd, vm_immediate_u(instruction))
    control.handled = yes
    out none
}

skill vm_execute_auipc(machine, instruction, control) {
    @value = vm_word_add(vm_word_number(machine.pc), vm_immediate_u(instruction))
    vm_set_register(machine, instruction.rd, value)
    control.handled = yes
    out none
}

skill vm_execute_jal(machine, instruction, control) {
    vm_set_register(machine, instruction.rd, vm_word_number(machine.pc + 4))
    control.next_pc = machine.pc + vm_immediate_j(instruction)
    control.handled = yes
    out none
}

skill vm_execute_jalr(machine, instruction, control) {
    (instruction.funct3 > 0) { vm_illegal(machine, instruction) control.handled = yes out none }
    @target = vm_effective_address(machine, instruction.rs1, vm_immediate_i(instruction))
    target.b0 = target.b0 - vm_mod(target.b0, 2)
    vm_set_register(machine, instruction.rd, vm_word_number(machine.pc + 4))
    control.next_pc = vm_word_address(target)
    control.handled = yes
    out none
}

skill vm_execute_branch(machine, instruction, control) {
    @left = vm_register(machine, instruction.rs1)
    @right = vm_register(machine, instruction.rs2)
    @take = no
    @valid = yes
    (instruction.funct3 == 0) { take = vm_word_equal(left, right) }
    (instruction.funct3 == 1) {
        (vm_word_equal(left, right) == no) { take = yes }
    }
    (instruction.funct3 == 4) { take = vm_word_signed_less(left, right) }
    (instruction.funct3 == 5) {
        (vm_word_signed_less(left, right) == no) { take = yes }
    }
    (instruction.funct3 == 6) { take = vm_word_unsigned_less(left, right) }
    (instruction.funct3 == 7) {
        (vm_word_unsigned_less(left, right) == no) { take = yes }
    }
    (instruction.funct3 == 2) { valid = no }
    (instruction.funct3 == 3) { valid = no }
    (valid == no) { vm_illegal(machine, instruction) }
    (valid == yes) {
        (take == yes) { control.next_pc = machine.pc + vm_immediate_b(instruction) }
    }
    control.handled = yes
    out none
}

skill vm_execute_load(machine, instruction, control) {
    @size = 0
    @signed = yes
    (instruction.funct3 == 0) { size = 1 }
    (instruction.funct3 == 1) { size = 2 }
    (instruction.funct3 == 2) { size = 4 }
    (instruction.funct3 == 4) { size = 1 signed = no }
    (instruction.funct3 == 5) { size = 2 signed = no }
    (size == 0) { vm_illegal(machine, instruction) control.handled = yes out none }
    @target = vm_effective_address(machine, instruction.rs1, vm_immediate_i(instruction))
    @address = vm_word_address(target)
    (vm_memory_check(machine, address, size, size, "load") == yes) {
        @value = vm_word_zero()
        value.b0 = vm_memory_raw_load8(machine.memory, address)
        (size > 1) { value.b1 = vm_memory_raw_load8(machine.memory, address + 1) }
        (size > 2) {
            value.b2 = vm_memory_raw_load8(machine.memory, address + 2)
            value.b3 = vm_memory_raw_load8(machine.memory, address + 3)
        }
        (signed == yes) {
            (size == 1) {
                (value.b0 > 127) { value.b1 = 255 value.b2 = 255 value.b3 = 255 }
            }
            (size == 2) {
                (value.b1 > 127) { value.b2 = 255 value.b3 = 255 }
            }
        }
        vm_set_register(machine, instruction.rd, value)
    }
    control.handled = yes
    out none
}

skill vm_execute_store(machine, instruction, control) {
    @size = 0
    (instruction.funct3 == 0) { size = 1 }
    (instruction.funct3 == 1) { size = 2 }
    (instruction.funct3 == 2) { size = 4 }
    (size == 0) { vm_illegal(machine, instruction) control.handled = yes out none }
    @target = vm_effective_address(machine, instruction.rs1, vm_immediate_s(instruction))
    @address = vm_word_address(target)
    (vm_memory_check(machine, address, size, size, "store") == yes) {
        vm_memory_store_word(machine.memory, address, vm_register(machine, instruction.rs2), size)
    }
    control.handled = yes
    out none
}

skill vm_execute_immediate(machine, instruction, control) {
    @left = vm_register(machine, instruction.rs1)
    @immediate = vm_word_number(vm_immediate_i(instruction))
    @value = vm_word_zero()
    @valid = yes
    (instruction.funct3 == 0) { value = vm_word_add(left, immediate) }
    (instruction.funct3 == 2) { value = vm_boolean_word(vm_word_signed_less(left, immediate)) }
    (instruction.funct3 == 3) { value = vm_boolean_word(vm_word_unsigned_less(left, immediate)) }
    (instruction.funct3 == 4) { value = vm_word_xor(left, immediate) }
    (instruction.funct3 == 6) { value = vm_word_or(left, immediate) }
    (instruction.funct3 == 7) { value = vm_word_and(left, immediate) }
    (instruction.funct3 == 1) {
        (instruction.funct7 == 0) { value = vm_word_shift_left(left, instruction.rs2) }
        (instruction.funct7 > 0) { valid = no }
    }
    (instruction.funct3 == 5) {
        (instruction.funct7 == 0) { value = vm_word_shift_right(left, instruction.rs2) }
        (instruction.funct7 == 32) { value = vm_word_shift_right_arithmetic(left, instruction.rs2) }
        (instruction.funct7 > 0) {
            (instruction.funct7 < 32) { valid = no }
            (instruction.funct7 > 32) { valid = no }
        }
    }
    (instruction.funct3 > 7) { valid = no }
    (valid == no) { vm_illegal(machine, instruction) }
    (valid == yes) { vm_set_register(machine, instruction.rd, value) }
    control.handled = yes
    out none
}

skill vm_execute_register(machine, instruction, control) {
    @left = vm_register(machine, instruction.rs1)
    @right = vm_register(machine, instruction.rs2)
    @value = vm_word_zero()
    @valid = yes
    (instruction.funct3 == 0) {
        (instruction.funct7 == 0) { value = vm_word_add(left, right) }
        (instruction.funct7 == 32) { value = vm_word_sub(left, right) }
        (instruction.funct7 > 0) {
            (instruction.funct7 < 32) { valid = no }
            (instruction.funct7 > 32) { valid = no }
        }
    }
    (instruction.funct3 == 1) {
        (instruction.funct7 == 0) { value = vm_word_shift_left(left, vm_mod(right.b0, 32)) }
        (instruction.funct7 > 0) { valid = no }
    }
    (instruction.funct3 == 2) {
        (instruction.funct7 == 0) { value = vm_boolean_word(vm_word_signed_less(left, right)) }
        (instruction.funct7 > 0) { valid = no }
    }
    (instruction.funct3 == 3) {
        (instruction.funct7 == 0) { value = vm_boolean_word(vm_word_unsigned_less(left, right)) }
        (instruction.funct7 > 0) { valid = no }
    }
    (instruction.funct3 == 4) {
        (instruction.funct7 == 0) { value = vm_word_xor(left, right) }
        (instruction.funct7 > 0) { valid = no }
    }
    (instruction.funct3 == 5) {
        (instruction.funct7 == 0) { value = vm_word_shift_right(left, vm_mod(right.b0, 32)) }
        (instruction.funct7 == 32) { value = vm_word_shift_right_arithmetic(left, vm_mod(right.b0, 32)) }
        (instruction.funct7 > 0) {
            (instruction.funct7 < 32) { valid = no }
            (instruction.funct7 > 32) { valid = no }
        }
    }
    (instruction.funct3 == 6) {
        (instruction.funct7 == 0) { value = vm_word_or(left, right) }
        (instruction.funct7 > 0) { valid = no }
    }
    (instruction.funct3 == 7) {
        (instruction.funct7 == 0) { value = vm_word_and(left, right) }
        (instruction.funct7 > 0) { valid = no }
    }
    (valid == no) { vm_illegal(machine, instruction) }
    (valid == yes) { vm_set_register(machine, instruction.rd, value) }
    control.handled = yes
    out none
}

skill vm_execute_fence(machine, instruction, control) {
    (instruction.funct3 > 0) { vm_illegal(machine, instruction) }
    control.handled = yes
    out none
}

skill vm_execute_environment(machine, instruction, control) {
    @ecall = vm_word_bytes(115, 0, 0, 0)
    @ebreak = vm_word_bytes(115, 0, 16, 0)
    (vm_word_equal(instruction.word, ecall) == yes) { vm_ecall(machine) control.handled = yes out none }
    (vm_word_equal(instruction.word, ebreak) == yes) {
        machine.halted = yes
        machine.halt_reason = "break"
        control.handled = yes
        out none
    }
    vm_illegal(machine, instruction)
    control.handled = yes
    out none
}

skill vm_execute(machine, instruction) {
    @control = VmControl { next_pc = machine.pc + 4 }
    (instruction.opcode == 55) { vm_execute_lui(machine, instruction, control) }
    (instruction.opcode == 23) { vm_execute_auipc(machine, instruction, control) }
    (instruction.opcode == 111) { vm_execute_jal(machine, instruction, control) }
    (instruction.opcode == 103) { vm_execute_jalr(machine, instruction, control) }
    (instruction.opcode == 99) { vm_execute_branch(machine, instruction, control) }
    (instruction.opcode == 3) { vm_execute_load(machine, instruction, control) }
    (instruction.opcode == 35) { vm_execute_store(machine, instruction, control) }
    (instruction.opcode == 19) { vm_execute_immediate(machine, instruction, control) }
    (instruction.opcode == 51) { vm_execute_register(machine, instruction, control) }
    (instruction.opcode == 15) { vm_execute_fence(machine, instruction, control) }
    (instruction.opcode == 115) { vm_execute_environment(machine, instruction, control) }
    (control.handled == no) { vm_illegal(machine, instruction) }
    out control
}

skill vm_step(machine) {
    (machine.halted == yes) { out none }
    (vm_mod(machine.pc, 4) > 0) {
        vm_trap(machine, "instruction address misaligned", "")
        out none
    }
    (vm_memory_check(machine, machine.pc, 4, 4, "instruction") == no) { out none }
    @instruction = vm_decode(vm_memory_load_word(machine.memory, machine.pc))
    @control = vm_execute(machine, instruction)
    (core.str.len(machine.trap) == 0) {
        machine.pc = control.next_pc
        machine.steps = machine.steps + 1
    }
    out none
}

skill vm_result(machine) {
    @registers = []
    @index = 0
    drum (32) {
        registers = core.group.add(registers, vm_word_hex(vm_register(machine, index)))
        index = index + 1
    }
    @reason = machine.halt_reason
    (core.str.len(machine.trap) > 0) { reason = "trap" }
    out VmResult {
        exit_code = machine.exit_code
        reason = reason
        pc = vm_number_hex(machine.pc)
        steps = machine.steps
        registers = registers
        stdout = machine.stdout
        stderr = machine.stderr
        files = machine.files
        trap = machine.trap
    }
}

skill vm_run(image, options) {
    @machine = vm_new_machine(options)
    vm_load(machine, image, options.load_address)
    (core.str.len(machine.trap) == 0) { vm_prepare_stack(machine, options) }
    @index = 0
    drum (options.step_limit) {
        (machine.halted == no) { vm_step(machine) }
        index = index + 1
    }
    (machine.halted == no) {
        @detail = core.str.add(core.num.text(options.step_limit), " instructions")
        vm_trap(machine, "step limit reached", detail)
    }
    out vm_result(machine)
}
