[BITS 16]

; data and stack segments setup
cli ; clear interrupts flag
xor ax, ax
mov ds, ax
mov ss, ax
mov sp, 0x7C00

; setup reading service
sti ; set interrupts flag
mov si, disk_address_packet
mov ah, 0x42

mov cx, PAYLOAD_SECTORS ; sectors left to read
read_payload:
  test cx, cx
  jz reading_done
  dec cx

  mov bx, 5 ; number of attempts
  .sector_reading_attempt:
    int 0x13
    jc .next_attempt
    test ah, ah
    jnz .next_attempt
    jmp .sector_reading_success
  .next_attempt:
    dec bx
    jz reading_failure
    ; reset disk system
    xor ah, ah
    int 0x13
    ; setup reading service
    mov word [disk_address_packet + 2], 0x1
    mov ah, 0x42
    jmp .sector_reading_attempt
  .sector_reading_success:

  ; setup reading service
  mov word  [disk_address_packet + 2], 0x1
  add word [disk_address_packet + 6], 0x20
  inc dword [disk_address_packet + 8]
  mov ah, 0x42

  jmp read_payload

reading_failure:
  mov ah, 0x0E
  xor bx, bx
  mov si, reading_failure_msg
  .print_char:
    lodsb
    test al, al
    jz .loop
    int 0x10
    jmp .print_char
  .loop:
    jmp .loop

reading_done:

; enable a20
mov ax, 0x2401
int 0x15
jnc a20_enabled

; fallback if enabling a20 failed
in al, 0x92
test al, 2
jnz a20_enabled
or al, 2
and al, 0xFE
out 0x92, al

a20_enabled:

; setup protected 32bit mode
cli ; clear interrupts flag
lgdt [gdt_descriptor]
cld
mov eax, cr0
or eax, 1
mov cr0, eax
jmp 0x8:next_line
[BITS 32]
next_line:
mov ax, 0x10
mov ss, ax
mov esp, 0x7C00
mov ds, ax
mov es, ax
mov fs, ax
mov gs, ax
[EXTERN kernel_entry]
call kernel_entry

[GLOBAL endless_loop]
endless_loop:
  hlt
  jmp endless_loop

reading_failure_msg: db "Reading failure", 0x0D, 0x0A, 0x00

align 4
disk_address_packet:
  db 0x10
  db 0x0
  dw 0x1
  dw 0x0000
  dw 0x07E0
  dq 0x1

gdt_descriptor:
  dw 0x17
  dd global_descriptors_table

align 8
global_descriptors_table:
  null_descriptor:
    dq 0x0

  code_segment_descriptor:
    dw 0xFFFF
    dw 0x0
    db 0x0
    db 0b10011010
    db 0b11001111
    db 0x0

  data_segment_descriptor:
    dw 0xFFFF
    dw 0x0
    db 0x0
    db 0b10010010
    db 0b11001111
    db 0x0

[GLOBAL vbr_code_end]
vbr_code_end:
times 510-($-$$) db 0
dw 0xAA55
