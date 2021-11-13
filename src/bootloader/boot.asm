%define ENDL 0x0D, 0x0A


; FAT12 HEADER

jmp short start
nop

bdb_oem: db "MSWIN4.1"
bdb_bytes_per_sector: dw 512
bdb_sectors_for_cluster: dw 1
bdb_reserved_sectors: dw 1
bdb_dir_entries_count: dw 0E0h
bdb_total_sectors: dw 2880
bdb_sectors_per_fat: dw 9
bdb_sectors_per_track: dw 18
bdb_heads: dw 2
bdb_hidden_sectors: dw 0 
bdb_large_sector_count: dw 0

; Extended boot record.
ebr_drive_number: db 0
ebr_signature: db 29h
ebr_volume_id: db 10h, 14h, 05h, 00h
ebr_volume_label: db "KESS OS"


org 0x7C00  ; Tells assembler where to expect our code to be loaded.
bits 16  ; Tells compiler to emit 32 code.


start:
    jmp main

puts:
    push si
    push ax


.loop:
    lodsb  ; This loads a byte from DS/SI into AL/AX/EAX and increments SI to numbytes loaded.
    or al, al ; If char is null then we finsished and will jump to .done
    jz .done ; Jumps if finished to done.

    ; *** CONTINUES IF CHAR IS NOT NULL ***
    mov ah, 0x0e ; Write char in TTY mode.
    mov bh, 0
    int 0x10  ; BIOS interrupt for video (printing text to screen).
    jmp .loop
    
    

.done:
    pop ax
    pop si
    ret


main:
    mov ax, 0 ; We can't put this value into ds directly so this our buffer.
    mov ds, ax   ; Sets ds to 0
    mov es, ax  ; Sets es to 0 (ds/es are segment registers).
    mov ss, ax ; Sets stack segement to 0.
    mov sp, 0x7C00  ; Stack grows downwards, we set to beginning of OS so it doesn't overwrite.
    mov si, start_msg
    call puts
    mov ax, 0
    int 16h
    mov si, msg
    call puts

    mov [ebr_drive_number], dl
    mov ax, 1
    mov cl, 1
    mov bx, 0x7E00
    call disk_read

    hlt

.halt:
    jmp .halt


; Disk routines

; Converts LBA address to a CHS address.
; Paremeters:
;  - ax: LBA address
; Returns: 
;  - cx: [bits 0-5]: sector number
;  - cx [bits 6-15]: cylinder.
;  - dh: head


lba_to_chs:
    xor dx, dx
    div word [bdb_sectors_per_track]
    inc dx
    mov cx, dx

    xor dx, dx
    div word [bdb_heads]
    mov dh, dl
    mov ch, al
    shl ah, 6
    or cl, ah

    pop ax
    mov dl, al
    pop ax
    ret



disk_read:
    push cx  ; temporarily saves CL (number of sectors to read.)
    call lba_to_chs
    pop ax

    mov ah, 02h
    mov di, 3

.retry:
    pusha
    stc
    int 13h
    jnc done1
    popa
    call disk_reset
    dec di
    cmp di, 0
    jne .retry


prep_error:
    mov si, floppy_error_msg
    mov ax, 0
    push ax
    push si

.fail:
    lodsb
    or al, al
    jz .halt_

    mov ah, 0x0e
    int 0x10
    jmp .fail


.halt_:
    mov ah, 0
    int 16h
    jmp 0FFFFh:0

done1:
    popa

disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    popa
    ret

msg: db ENDL, ENDL, "Welcome To KessOS", ENDL, "Made By Ian", 0
floppy_error_msg: db ENDL, "The Damn Floppy Disk Failed. Press a key to restart."
start_msg: db ENDL, "To Start KessOS Press Any Key", ENDL, 0
