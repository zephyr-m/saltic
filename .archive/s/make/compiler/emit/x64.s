use core

X64Instruction = Box {
    op = ""
    register = ""
    value = none
}

X64Immediate = Box {
    width = 0
    value = 0
}

skill x64_u8(value) {
    out X64Immediate {
        width = 8
        value = value
    }
}

skill x64_u64(value) {
    out X64Immediate {
        width = 64
        value = value
    }
}

skill x64_mov(register, value) {
    out X64Instruction {
        op = "MOV_REG"
        register = register
        value = value
    }
}

skill x64_syscall() {
    out X64Instruction {
        op = "SYSCALL"
    }
}

skill x64_write(fd, buffer, length) {
    @code = []
    code = core.group.add(code, x64_mov("rax", 1))
    code = core.group.add(code, x64_mov("rdi", fd))
    code = core.group.add(code, x64_mov("rsi", buffer))
    code = core.group.add(code, x64_mov("rdx", length))
    code = core.group.add(code, x64_syscall())
    out code
}

skill x64_exit(code_value) {
    @code = []
    code = core.group.add(code, x64_mov("rax", 60))
    code = core.group.add(code, x64_mov("rdi", code_value))
    code = core.group.add(code, x64_syscall())
    out code
}
