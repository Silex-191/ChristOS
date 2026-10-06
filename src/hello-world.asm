[BITS 16]
[ORG 0x7C00]
cli

; STACK AND DATA SEGMENT SETUP
xor ax, ax
mov ss, ax
mov sp, 0x7C00
mov ds, ax

mov ah, 0x0E
mov bx, msg
print_char:
  mov al, byte [bx]
  test al, al
  jz str_end
  inc bx
  int 0x10
  jmp print_char
str_end:

sti
loop:
  jmp loop

msg: db "Hello, world!", 0x0D, 0x0A, 0x00

times 510-($-$$) db 0
dw 0xAA55
