use core

FW_CFG_DEVICE = [4112, 0]
FW_CFG_DIRECTORY = 25
FW_CFG_DATA_OFFSET = 0
FW_CFG_SELECTOR_OFFSET = 8
FW_CFG_DMA_OFFSET = 20
FW_CFG_CONFIG = [33056, 0]
FW_CFG_DESCRIPTOR = [33056, 4096]

skill fw_cfg_select(selector) {
    core.mem.store16(FW_CFG_DEVICE, FW_CFG_SELECTOR_OFFSET, selector * 256)
    out none
}

skill fw_cfg_byte() {
    out core.mem.load8(FW_CFG_DEVICE, FW_CFG_DATA_OFFSET)
}

skill fw_cfg_skip(count) {
    @index = 0
    drum (count) {
        fw_cfg_byte()
        index = index + 1
    }
    out none
}

skill fw_cfg_u32() {
    @first = fw_cfg_byte()
    @second = fw_cfg_byte()
    @third = fw_cfg_byte()
    @fourth = fw_cfg_byte()
    out first * 16777216 + second * 65536 + third * 256 + fourth
}

skill fw_cfg_ramfb_name_byte(index) {
    (index == 0) { out 101 }
    (index == 1) { out 116 }
    (index == 2) { out 99 }
    (index == 3) { out 47 }
    (index == 4) { out 114 }
    (index == 5) { out 97 }
    (index == 6) { out 109 }
    (index == 7) { out 102 }
    (index == 8) { out 98 }
    out 0
}

skill fw_cfg_read_name() {
    @same = yes
    @index = 0
    drum (56) {
        @actual = fw_cfg_byte()
        (index < 10) {
            @expected = fw_cfg_ramfb_name_byte(index)
            ((actual == expected) == no) {
                same = no
            }
        }
        index = index + 1
    }
    out same
}

skill fw_cfg_find_ramfb() {
    fw_cfg_select(FW_CFG_DIRECTORY)
    @count = fw_cfg_u32()
    @selector = 0
    @index = 0

    drum (count) {
        fw_cfg_skip(4)
        @high = fw_cfg_byte()
        @low = fw_cfg_byte()
        fw_cfg_skip(2)
        @same = fw_cfg_read_name()
        (same == yes) {
            selector = high * 256 + low
        }
        index = index + 1
    }

    out selector
}

skill fw_cfg_write_bytes(address, bytes) {
    @index = 0
    @count = core.group.count(bytes)
    drum (count) {
        core.mem.store8(address, index, core.group.at(bytes, index))
        index = index + 1
    }
    out none
}

skill fw_cfg_configure_ramfb(framebuffer) {
    @selector = fw_cfg_find_ramfb()
    (selector == 0) {
        out error.RamfbNotFound
    }

    @configuration = [
        0, 0, 0, 0, 130, 0, 0, 0,
        52, 50, 82, 88,
        0, 0, 0, 0,
        0, 0, 5, 0,
        0, 0, 2, 208,
        0, 0, 20, 0,
    ]
    fw_cfg_write_bytes(FW_CFG_CONFIG, configuration)

    @selector_high = selector / 256
    @selector_low = selector - selector_high * 256
    @descriptor = [
        selector_high, selector_low, 0, 24,
        0, 0, 0, 28,
        0, 0, 0, 0, 129, 32, 0, 0,
    ]
    fw_cfg_write_bytes(FW_CFG_DESCRIPTOR, descriptor)

    core.mem.store32(FW_CFG_DEVICE, FW_CFG_DMA_OFFSET, 1056897)

    (core.mem.load32(FW_CFG_DESCRIPTOR, 0) == 0) {
        out framebuffer
    }
    out error.RamfbDmaFailed
}
