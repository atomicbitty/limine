#include <lib/asm.h>

ASM_BASIC(
    ".section .entry\n\t"

    "cld\n\t"

    // Zero out .bss
    "xor al, al\n\t"
    "mov edi, OFFSET bss_begin\n\t"
    "mov ecx, OFFSET bss_end\n\t"
    "sub ecx, OFFSET bss_begin\n\t"
    "rep stosb\n\t"

    "mov ebx, OFFSET main\n\t"
    "jmp ebx\n\t"
);

#include <stdint.h>
#include <stddef.h>
#include <gzip/tinf.h>

struct module_header {
    size_t size;
    size_t padding[3];
    char   start[];
};

__attribute__((noreturn))
void main(uint8_t *compressed_stage2, size_t stage2_size,
          struct module_header *modules, size_t modules_count,
          uint8_t boot_drive) {
    // The decompressor should decompress compressed_stage2 to address 0x4000.
    volatile uint8_t *dest = (volatile uint8_t *)0x4000;

    tinf_gzip_uncompress(dest, compressed_stage2, stage2_size);

    __attribute__((noreturn))
    void (*stage2)(struct module_header *, size_t, uint8_t) = (void *)dest;

    stage2(modules, modules_count, boot_drive);
}
