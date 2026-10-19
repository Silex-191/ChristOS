void endless_loop();

extern int __bss_start;
extern int __bss_end;

void kernel_entry() {
  int *bss = &__bss_start;
  while (bss < &__bss_end) {
    *bss = 0;
    bss++;
  }

  volatile unsigned short int* vga = (volatile unsigned short int*) 0xB8000;

  while (vga != (volatile unsigned short int*) 0xB8FA0) {
    *vga = 0;
    vga++;
  }

  vga = (volatile unsigned short int*) 0xB8720;

  const char *text = "Hello mr.Stark!";

  for (int i = 0; text[i] != '\0'; i++) {
    vga[i] = (0x0B << 8) | text[i];
  }

  endless_loop();
}
