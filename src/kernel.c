void endless_loop();

//void kernel_entry() {
//  *((short int*) 0xB8000) = 0;
//  endless_loop();
//}

void kernel_entry() {
    volatile unsigned short int* vga = (volatile unsigned short int*) 0xB8000;

    while (vga != (volatile unsigned short int*) 0xB8F9E) {
      *vga = 0;
      vga++;
    }

    vga = (volatile unsigned short int*) 0xB8720;

    const char *text = "HELLO WORLD";

    for (int i = 0; text[i] != '\0'; i++) {
        vga[i] = (0x0B << 8) | text[i];
    }

    endless_loop();
}
