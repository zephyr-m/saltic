OUTPUT_ARCH(riscv)
ENTRY(platform_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 128M
}

SECTIONS
{
    . = ORIGIN(RAM);

    .text : ALIGN(4)
    {
        KEEP(*(.text.platform_start))
        *(.text*)
    } > RAM

    .rodata : ALIGN(8)
    {
        *(.rodata*)
    } > RAM

    .data : ALIGN(8)
    {
        *(.data*)
    } > RAM

    .bss (NOLOAD) : ALIGN(8)
    {
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        __bss_end = .;
    } > RAM

    __stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
