[BITS 16]
cli ; clear interrupts flag

; data and stack segments setup
xor ax, ax
mov ds, ax
mov ss, ax
mov sp, 0x7C00

; extra segment and bx pointing after vbr code
mov ax, 0x7E0
mov es, ax
xor bx, bx

; setuping reading service
mov ax, 0x201
mov cx, 0x2
mov dh, 0x0

; segments left to read
mov bp, PAYLOAD_SECTORS

; At this moment, si and di registers are free
; ax = 0x201 - const
; bx = 0x000 - const
.segment_reading_loop:
  test bp, bp
  jz .reading_done

  mov si, 5 ; number of attempts
  .sector_reading_attempt:
    int 0x13
    jnc .sector_reading_success
    dec si
    jz .reading_failure
    mov ax, 0x201
    jmp .sector_reading_attempt
  .sector_reading_success:
  dec bp

  ; shift extra segment and setup service
  mov ax, es
  add ax, 0x20
  mov es, ax
  mov ax, 0x0201

  inc cl ; next sector
  cmp cl, 19
  jz .next_head
  jmp .segment_reading_loop
  .next_head:
    mov cl, 1
    inc dh
    cmp dh, 2
    jz .next_cylinder
    jmp .segment_reading_loop
    .next_cylinder:
      xor dh, dh
      inc ch
      jmp .segment_reading_loop

.reading_failure:
  mov ah, 0x0E
  mov bx, .reading_failure_msg
  .print_char:
    mov al, byte [bx]
    test al, al
    jz .loop
    inc bx
    int 0x10
    jmp .print_char

.loop:
  jmp .loop

.reading_done:

lgdt [.gdt_descriptor]
cld
mov eax, cr0
or eax, 1
mov cr0, eax
jmp 0x8:.next_line
[BITS 32]
.next_line:
mov ax, 0x10
mov ds, ax
mov ss, ax
mov es, ax
mov fs, ax
mov gs, ax
[EXTERN kernel_entry]
call kernel_entry

[GLOBAL endless_loop]
endless_loop:
  jmp endless_loop

.reading_failure_msg: db "Reading failure", 0x0D, 0x0A, 0x00

.gdt_descriptor:
  dw 0x17
  dd .gdt

align 8
.gdt:
  .null_descriptor:
    dq 0x0

  .code_segment_descriptor:
    dw 0xFFFF
    dw 0x0
    db 0x0
    db 0b10011010
    db 0b11001111
    db 0x0

  .data_segment_descriptor:
    dw 0xFFFF
    dw 0x0
    db 0x0
    db 0b10010010
    db 0b11001111
    db 0x0

times 510-($-$$) db 0
dw 0xAA55
