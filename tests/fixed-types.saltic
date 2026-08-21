use core

skill checked_arithmetic() {
    @byte = u8(250)
    @byte_sum = byte + u8(5)
    @word = u16(60000)
    @word_sum = word + u16(5535)
    @signed = i32(0 - 2000000000)
    @signed_sum = signed + i32(2000000001)
    @difference = u8(10) - u8(3)
    @product = u16(200) * u16(300)
    @quotient = u32(4000000000) / u32(2)
    @signed_product = i32(0 - 7) * i32(6)
    @signed_quotient = i32(0 - 84) / i32(2)

    core.io.show("u8 arithmetic: ", byte_sum)
    core.io.show("u16 arithmetic: ", word_sum)
    core.io.show("i32 arithmetic: ", signed_sum)
    core.io.show("u8 subtraction: ", difference)
    core.io.show("u16 multiplication: ", product)
    core.io.show("u32 division: ", quotient)
    core.io.show("i32 multiplication: ", signed_product)
    core.io.show("i32 division: ", signed_quotient)
    core.io.show("u32 comparison: ", u32(4294967295) > u32(1))
    core.io.show("i32 comparison: ", i32(0 - 1) < i32(0))

    @byte_overflow = u8(255) + u8(1) rescue |err| {
        core.io.show("переполнение u8: ", err)
        u8(0)
    }
    @signed_overflow = i32(2147483647) + i32(1) rescue |err| {
        core.io.show("переполнение i32: ", err)
        i32(0)
    }
    @unsigned_underflow = u8(0) - u8(1) rescue |err| {
        core.io.show("выход ниже границы u8: ", err)
        u8(0)
    }

    core.io.show("u8 after overflow: ", byte_overflow)
    core.io.show("i32 after overflow: ", signed_overflow)
    core.io.show("u8 after underflow: ", unsigned_underflow)
    out none
}

skill checked_conversions() {
    @byte = u8(255)
    @word = core.u16.from(byte)
    @double_word = core.u32.from(word)
    @signed = core.i32.from(word)
    @narrow = core.u8.from(u16(255))

    core.io.show("u8 to u16: ", word)
    core.io.show("u16 to u32: ", double_word)
    core.io.show("u16 to i32: ", signed)
    core.io.show("checked narrowing: ", narrow)

    @failed = core.u8.from(u16(256)) rescue |err| {
        core.io.show("ошибка сужения до u8: ", err)
        u8(0)
    }
    @failed_signed = core.i32.from(u32(4294967295)) rescue |err| {
        core.io.show("ошибка преобразования в i32: ", err)
        i32(0)
    }
    @failed_unsigned = core.u32.from(i32(0 - 1)) rescue |err| {
        core.io.show("ошибка преобразования в u32: ", err)
        u32(0)
    }
    core.io.show("u8 after narrowing: ", failed)
    core.io.show("i32 after conversion: ", failed_signed)
    core.io.show("u32 after conversion: ", failed_unsigned)
    out none
}

skill bit_operations() {
    @left = bits32(4042322160)
    @right = bits32(252645135)

    core.io.show("bits and: ", core.bits32.and(left, right))
    core.io.show("bits or: ", core.bits32.or(left, right))
    core.io.show("bits xor: ", core.bits32.xor(left, right))
    core.io.show("bits not: ", core.bits32.not(bits32(0)))
    core.io.show("bits shift left: ", core.bits32.shift_left(bits32(1), u8(31)))
    core.io.show("bits shift right: ", core.bits32.shift_right(bits32(2147483648), u8(31)))
    out none
}

skill typed_memory() {
    @memory = address(u32(4096))
    core.mem.store8(memory, usize(0), u8(171))
    core.mem.store16(memory, usize(2), u16(52719))
    core.mem.store32(memory, usize(4), u32(3735928559))

    @next = core.address.add(memory, usize(4))
    core.io.show("load8: ", core.mem.load8(memory, usize(0)))
    core.io.show("load16: ", core.mem.load16(memory, usize(2)))
    core.io.show("load32: ", core.mem.load32(next, usize(0)))
    out none
}

program() {
    core.io.show("u8 limits: ", u8(0), " ", u8(255))
    core.io.show("u16 limits: ", u16(0), " ", u16(65535))
    core.io.show("u32 limits: ", u32(0), " ", u32(4294967295))
    core.io.show("i32 limits: ", i32(0 - 2147483648), " ", i32(2147483647))
    core.io.show("usize: ", usize(4294967295))

    checked_arithmetic()
    checked_conversions()
    bit_operations()
    typed_memory()
    out none
}
