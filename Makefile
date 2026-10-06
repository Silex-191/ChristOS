# =============================================================================
# Variables

NASM = nasm -f bin
QEMU = qemu-system-i386 -cpu pentium2 -m 1g \
      -drive file=boot.img,format=raw,if=floppy \
      -monitor stdio -device VGA


# =============================================================================
# Tasks

all: clean build test

.tmp/boot.bin: src/boot.asm
	$(NASM) src/boot.asm -o .tmp/boot.bin

boot.img: .tmp/boot.bin
	dd if=/dev/zero of=boot.img bs=1024 count=1440
	dd if=.tmp/boot.bin of=boot.img conv=notrunc
	dd if=src/text.txt of=boot.img conv=notrunc seek=1

build: boot.img

clean:
	rm -f *.img
	rm -rf .tmp
	mkdir .tmp

test: build
	$(QEMU)

debug: build
	$(QEMU) -s -S & gdb -iex 'add-auto-load-safe-path ./.gdbinit'

.PHONY: all build clean test debug
