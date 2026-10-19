# =============================================================================
# Variables

NASM = nasm
NASM_FLAGS = -felf

GCC = gcc
GCC_FLAGS = -std=c99 -m32 -O2 -ffreestanding \
						-no-pie -fno-pie -mno-sse -fno-stack-protector -Wall -Wextra

QEMU = qemu-system-i386
QEMU_FLAGS = -cpu pentium2 -m 1g \
             -drive if=none,id=usbdrive,format=raw,file=boot.img \
             -usb -device usb-storage,drive=usbdrive \
             -monitor stdio -device VGA

LD = ld
LD_FLAGS = -m elf_i386 -z noexecstack --no-warn-rwx-segments -T link.ld

SECTOR_SIZE = 512
MAX_PAYLOAD_SECTORS = 128

# Default target drive for flashing (override via: make flash DRIVE=/dev/sdX)
DRIVE ?= /dev/sdX

# =============================================================================
# Source Files & Objects

C_SRCS := $(shell find src -type f -name '*.c' 2>/dev/null)
ASM_SRCS := $(filter-out src/boot.asm, $(shell find src -type f -name '*.asm' 2>/dev/null))

C_OBJS := $(patsubst src/%.c, .tmp/%.o, $(C_SRCS))
ASM_OBJS := $(patsubst src/%.asm, .tmp/%.o, $(ASM_SRCS))

KERNEL_OBJS := $(C_OBJS) $(ASM_OBJS)

# =============================================================================
# Targets

all: clean build test

clean:
	@rm -f *.img
	@rm -rf .tmp
	@mkdir -p .tmp

.tmp/%.o: src/%.c
	@mkdir -p $(dir $@)
	$(GCC) $(GCC_FLAGS) -c $< -o $@

.tmp/%.o: src/%.asm
	@mkdir -p $(dir $@)
	$(NASM) $(NASM_FLAGS) $< -o $@

.tmp/boot.o: src/boot.asm $(KERNEL_OBJS) link.ld
	@mkdir -p $(dir $@)
	@$(NASM) $(NASM_FLAGS) -dPAYLOAD_SECTORS=191 src/boot.asm -o .tmp/boot.dummy.o
	@$(LD) $(LD_FLAGS) .tmp/boot.dummy.o $(KERNEL_OBJS) -o .tmp/os.dummy.elf
	@objcopy -I elf32-i386 -O binary .tmp/os.dummy.elf .tmp/os.dummy.bin
	@PAYLOAD_SIZE=$$(( $$(stat -c %s .tmp/os.dummy.bin) - $(SECTOR_SIZE) )); \
	PAYLOAD_SECTORS=$$(( ($$PAYLOAD_SIZE + $(SECTOR_SIZE) - 1) / $(SECTOR_SIZE) )); \
	if [ $$PAYLOAD_SECTORS -gt $(MAX_PAYLOAD_SECTORS) ]; then \
		echo "ERROR: PAYLOAD is too large: $$PAYLOAD_SECTORS sectors, max is $(MAX_PAYLOAD_SECTORS)"; \
		exit 1; \
	fi; \
	echo "=> Kernel size: $$PAYLOAD_SIZE bytes ($$PAYLOAD_SECTORS sectors)"; \
	VBR_HEX=$$(nm .tmp/boot.dummy.o | grep vbr_code_end | awk '{print $$1}'); \
	VBR_DEC=$$(printf "%d" 0x$$VBR_HEX); \
	VBR_FREE=$$(( 510 - $$VBR_DEC )); \
	echo "=> VBR space: used $$VBR_DEC / 510 bytes (free: $$VBR_FREE bytes)"; \
	$(NASM) $(NASM_FLAGS) -dPAYLOAD_SECTORS=$$PAYLOAD_SECTORS src/boot.asm -o $@

.tmp/os.elf: .tmp/boot.o $(KERNEL_OBJS) link.ld
	$(LD) $(LD_FLAGS) .tmp/boot.o $(KERNEL_OBJS) -o .tmp/os.elf

.tmp/os.bin: .tmp/os.elf
	objcopy -I elf32-i386 -O binary .tmp/os.elf .tmp/os.bin

boot.img: .tmp/os.bin
	dd if=/dev/zero of=boot.img bs=1M count=4
	dd if=.tmp/os.bin of=boot.img conv=notrunc

build: boot.img

test: build
	$(QEMU) $(QEMU_FLAGS)

debug: clean
	$(MAKE) build
	$(QEMU) $(QEMU_FLAGS) -s -S & gdb -iex 'add-auto-load-safe-path ./.gdbinit'

# Flash to a real USB drive
flash: clean
	$(MAKE) build
	@if [ "$(DRIVE)" = "/dev/sdX" ]; then \
		echo "ERROR: You did not specify a drive!"; \
		echo "Usage: make flash DRIVE=/dev/sdX (where /dev/sdX is your USB drive, e.g., /dev/sdb)"; \
		exit 1; \
	fi
	-sudo umount $(DRIVE)* 2>/dev/null || true
	sudo dd if=boot.img of=$(DRIVE) bs=4M status=progress
	sudo sync

.PHONY: all build clean test debug flash
