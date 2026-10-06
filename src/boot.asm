[BITS 16]
[ORG 0x7C00]
cli

; stack and data segments setup
xor ax, ax
mov ss, ax
mov sp, 0x7C00
mov ds, ax

; extra segment and bx pointing after bootloader code
mov ax, 0x7E0
mov es, ax
xor bx, bx

; setuping reading service
mov ax, 0x0201
mov cx, 2
mov dh, 0

mov bp, 355 ; segments left to read
segment_read_loop:
  test bp, bp
  jz reading_done
  int 0x13
  jc reading_failure
  dec bp

  ; shift extra segment and setup service
  mov ax, es
  add ax, 0x20
  mov es, ax
  mov ax, 0x0201

  inc cl ; next sector
  cmp cl, 19
  jz next_head
  jmp segment_read_loop
  next_head:
    mov cl, 1
    inc dh
    cmp dh, 2
    jz next_cylinder
    jmp segment_read_loop
    next_cylinder:
      xor dh, dh
      inc ch
      jmp segment_read_loop
reading_done:

sti
loop:
  jmp loop

reading_failure:
  mov ah, 0x0E
  mov bx, error_msg
  print_char:
    mov al, byte [bx]
    test al, al
    jz reading_done
    inc bx
    int 0x10
    jmp print_char

error_msg: db "FATAL ERROR", 0x0D, 0x0A, 0x00

times 510-($-$$) db 0
dw 0xAA55
