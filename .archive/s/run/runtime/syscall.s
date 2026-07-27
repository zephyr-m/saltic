Syscall = Box {
    name = ""
    number = 0
    args = []
}

SyscallOut = Box {
    ok = yes
    value = none
}

LinuxX64Syscall = Box {
    abi = "linux.x86_64"
    rax = 0
    rdi = none
    rsi = none
    rdx = none
}

skill syscall_write(fd, buffer) {
    out Syscall {
        name = "write"
        number = 1
        args = [fd, buffer]
    }
}

skill syscall_exit(code) {
    out Syscall {
        name = "exit"
        number = 60
        args = [code]
    }
}

skill syscall_linux_write(fd, buffer, length) {
    out LinuxX64Syscall {
        rax = 1
        rdi = fd
        rsi = buffer
        rdx = length
    }
}

skill syscall_linux_exit(code) {
    out LinuxX64Syscall {
        rax = 60
        rdi = code
    }
}
