org 0x7c00
bits 16

start:
    jmp .skip_bpb ; Workaround for some BIOSes that require this stub
    nop

    ; Some BIOSes will do a funny and decide to overwrite bytes of code in
    ; the section where a FAT BPB would be, potentially overwriting
    ; bootsector code.
    ; Avoid that by filling the BPB area with 0s
    times 87 db 0

  .skip_bpb:
    cli
    cld
    jmp 0x0000:.initialise_cs
  .initialise_cs:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x4000
    sti

    ; Some BIOSes don't pass the correct boot drive number,
    ; so we need to do the job
  .check_drive:
    ; Limine isn't made for floppy disks, these are dead anyways.
    ; So if the value the BIOS passed is <0x80, just assume it has passed
    ; an incorrect value
    test dl, 0x80
    jz .fix_drive

    ; Drive numbers from 0x80..0x8f should be valid
    test dl, 0x70
    jz .continue

  .fix_drive:
    ; Try to fix up the mess the BIOS have done
    mov dl, 0x80

  .continue:
    mov si, LoadingMsg
    call simple_print

    ; ****************** Load stage 1.5 ******************

    ; Make sure int 13h extensions are supported
    mov ah, 0x41
    mov bx, 0x55aa
    int 0x13
    jc err_reading_disk
    cmp bx, 0xaa55
    jne err_reading_disk

    ; If int 13h extensions are supported, then we are definitely running on
    ; a 386+. We have no idea whether the upper 16 bits of esp are cleared, so
    ; make sure that is the case now.
    mov esp, 0x4000

    mov eax, dword [stage15_sector]
    mov bx, 0x7e00
    mov cx, 1
    call read_sectors

    jc err_reading_disk

    jmp 0x7e00

err_reading_disk:
    mov si, ErrReadDiskMsg
    call simple_print
    jmp halt

err_enabling_a20:
    mov si, ErrEnableA20Msg
    call simple_print
    jmp halt

halt:
    hlt
    jmp halt

; Data

LoadingMsg db 0x0D, 0x0A, 'Limine', 0x0D, 0x0A, 0x0A, 0x00
ErrReadDiskMsg db 0x0D, 0x0A, 'Disk err', 0x00
ErrEnableA20Msg db 0x0D, 0x0A, 'A20 err', 0x00

times 0xda-($-$$) db 0
times 6 db 0

; Includes

%include 'simple_print.inc'
%include 'disk.inc'

times 0x1b0-($-$$) db 0
stage15_sector: dd 1

times 0x1b8-($-$$) db 0
times 510-($-$$) db 0
dw 0xaa55

; ********************* Stage 1.5 *********************

stage15:
    push es
    push 0x7000
    pop es
    mov eax, dword [stage15_sector]
    inc eax
    xor bx, bx
    mov cx, 62
    call read_sectors
    pop es
    jc err_reading_disk

    call enable_a20
    jc err_enabling_a20

    call load_gdt

    cli

    mov eax, cr0
    or al, 1
    mov cr0, eax

    jmp 0x18:.pmode
    bits 32
  .pmode:
    mov ax, 0x20
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov esi, modules_start
    mov ecx, modules_end - modules_start
    mov ebx, dword [modules_count_s]

    push stage2.size
    push (stage2 - 0x8000) + 0x70000

    call 0x70000

bits 16
%include 'a20_enabler.inc'
%include 'gdt.inc'

times 1024-($-$$) db 0

incbin '../decompressor/decompressor.bin'

align 16
stage2:
incbin '../stage2.bin.gz'
.size: equ $ - stage2

%assign modules_count 0

%macro module 1
%1_start:
dd %1_end - %1_start
dd 0, 0, 0
%defstr %1_path ../../modules/%1/%1.mod
incbin %1_path
align 16
%1_end:
%assign modules_count modules_count+1
%endmacro

align 16
modules_start:
%include '../../builtin_modules.list'
modules_end:

modules_count_s: dd modules_count

times 32768-($-$$) db 0
