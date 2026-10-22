target remote localhost:1234
set disassembly-flavor intel

symbol-file .tmp/os.elf
b kernel_entry
c
