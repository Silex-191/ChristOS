# =============================================================================
# Variables

NASM = nasm
NASM_FLAGS = -felf -dPAYLOAD_SECTORS=100

GCC = gcc
GCC_FLAGS = -std=c99 -m32 -O2 -ffreestanding \
						-no-pie -fno-pie -mno-sse -fno-stack-protector

QEMU = qemu-system-i386
QEMU_FLAGS = -cpu pentium2 -m 1g \
						 -drive file=boot.img,format=raw,if=floppy \
             -monitor stdio -device VGA

PAYLOAD = src/boot.asm

SECTOR_SIZE = 512
MAX_PAYLOAD_SECTORS = 128

# Payload size in bytes
#PAYLOAD_SIZE := $(shell stat -c %s "$(PAYLOAD)")

# Number of sectors required by payload, rounded up
#PAYLOAD_SECTORS := $(shell echo $$((($(PAYLOAD_SIZE) + $(SECTOR_SIZE) - 1) / $(SECTOR_SIZE))))

# Check payload size
#ifeq ($(shell test $(PAYLOAD_SECTORS) -le $(MAX_PAYLOAD_SECTORS) && echo OK),)
#$(error PAYLOAD is too large: $(PAYLOAD_SECTORS) sectors, maximum is $(MAX_PAYLOAD_SECTORS))
#endif


# =============================================================================
# Targets

all: clean build test

clean:
	rm -f *.img
	rm -rf .tmp
	mkdir .tmp

kernel.o: src/kernel.c
	$(GCC) $(GCC_FLAGS) -c src/kernel.c -o .tmp/kernel.o

boot.o: src/boot.asm
	$(NASM) $(NASM_FLAGS) src/boot.asm -o .tmp/boot.o

os.elf: boot.o kernel.o link.ld
	ld -m elf_i386 .tmp/boot.o .tmp/kernel.o -T link.ld -o .tmp/os.elf

os.bin: os.elf
	objcopy -I elf32-i386 -O binary .tmp/os.elf .tmp/os.bin

boot.img: os.bin
	dd if=/dev/zero of=boot.img bs=1024 count=1440
	dd if=.tmp/os.bin of=boot.img conv=notrunc

build: boot.img

test: build
	$(QEMU) $(QEMU_FLAGS)

debug: clean
	$(MAKE) build
	$(QEMU) $(QEMU_FLAGS) -s -S & gdb -iex 'add-auto-load-safe-path ./.gdbinit'

.PHONY: all build clean test debug
