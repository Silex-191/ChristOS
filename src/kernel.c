#include <stdarg.h>
#include <stddef.h>

void endless_loop();

extern int __bss_start;
extern int __bss_end;

typedef unsigned char      u8;
typedef unsigned short     u16;
typedef unsigned int       u32;
typedef unsigned long long u64;

typedef signed char        s8;
typedef signed short       s16;
typedef signed int         s32;
typedef signed long long   s64;

#define VGA_START       0xB8000
#define VGA_END         0xB8FA0
#define VGA_SIZE        0xFA0
#define VGA_WIDTH       80
#define VGA_HEIGHT      25
#define VGA_SYMBOL_SIZE 2

void *memmove(void *dst, const void *src, size_t n) {
  void *res = dst;
  if (src > dst) {
    for (size_t i = 0; i < n; i++) {
      *((u8*) dst++) = *((u8*) src++);  
    }
  }
  else {
    dst += n - 1;
    src += n - 1;
    for (size_t i = 0; i < n; i++) {
      *((u8*) dst--) = *((u8*) src--);  
    }
  }
  return res;
}

void *memset(void *s, int c, size_t n) {
  void* res = s;
  for (size_t i = 0; i < n; i++) {
    *((u8*) s++) = (u8) c;
  }
  return res;
}

void initialize_bss() {
  memset(&__bss_start, 0, (size_t) (__bss_end - __bss_start));
}

void vga_clear_screen() {
  memset((void*) VGA_START, 0, (size_t) VGA_SIZE);
}

void vga_print_char(char c, size_t x, size_t y) {
  *((volatile u16*) VGA_START + x + VGA_WIDTH * y) = (0x0F << 8) | c;
}

void vga_fill_screen(u16 symbol) {
  volatile u16 *vga = (volatile u16*) VGA_START;
  while (vga < (volatile u16*) VGA_END) {
    *(vga++) = symbol;
  }
}

void vga_scroll_up() {
  memmove((void*) VGA_START, (void*) VGA_START + VGA_SYMBOL_SIZE * VGA_WIDTH,
          (size_t) VGA_SIZE - VGA_SYMBOL_SIZE * VGA_WIDTH);
  memset((void*) VGA_END - VGA_SYMBOL_SIZE * VGA_WIDTH, 0, VGA_SYMBOL_SIZE * VGA_WIDTH);
}

// DRAFT

#define assert(cond) \
    if (!(cond)) { \
        kernel_panic("Assertion failed: %s at (%s, line #%d)\n", #cond, __FILE__, __LINE__); \
    }

#define arena ((void*) 0x100000)
#define arena_size 0x100000
#define arena_end ((void*) ((size_t) arena + arena_size))
#define alignment(x, a) ((void*) (((size_t) x + a - 1) & ~(a - 1)))
static void* cursor = arena;
void clear_interrupts_flag();
static size_t cursor_x;
static size_t cursor_y;

void* malloc_immortal(size_t size, size_t alignment) {
  if (alignment(cursor, alignment) + size > arena_end) {
    return NULL;
  }
  void* ptr = alignment(cursor, alignment);
  cursor = ptr + size;
  return ptr;
}

int pow(int base, int exp) {
  int result = 1;
  for (int i = 0; i < exp; i++)
  result *= base;
  return result;
}

void put_char(char c) {
  vga_print_char(c, cursor_x, cursor_y);
  if (++cursor_x == VGA_WIDTH) {
    cursor_x = 0;
    if (++cursor_y == VGA_HEIGHT) {
      vga_scroll_up();
      cursor_y = VGA_HEIGHT - 1;
    }
  }
}

static void put_unsigned_decimal(unsigned int value) {
  unsigned int divisor = 1;
  while (value / divisor >= 10)
    divisor *= 10;
  do {
    put_char('0' + value / divisor);
    value %= divisor;
    divisor /= 10;
  } while (divisor);
}

void vprintf(const char* fmt, va_list args) {
  for (size_t i = 0; fmt[i] != '\0'; i++) {
    if (fmt[i] == '%') {
      switch (fmt[++i]) {
        case 'c': {
          put_char((char) va_arg(args, int));
          break;
        }
        case 's': {
          char* str = va_arg(args, char*);
          for (size_t j = 0; str[j] != '\0'; j++)
            put_char(str[j]);
          break;
        }
        case 'd': {
          int num = va_arg(args, int);
          unsigned int value;
          if (num < 0) {
            put_char('-');
            value = 0u - (unsigned int) num;
          } else {
            value = (unsigned int) num;
          }
          put_unsigned_decimal(value);
          break;
        }
        case 'x': {
          unsigned int num = va_arg(args, unsigned int);
          put_char('0');
          put_char('x');
          for (int j = 7; j >= 0; j--) {
            unsigned int nibble = (num >> (j * 4)) & 0xF;
            if (nibble < 10)
              put_char('0' + nibble);
            else
              put_char('A' + (nibble - 10));
          }
          break;
        }
      }
    } else if (fmt[i] == '\n') {
      cursor_x = 0;
      if (++cursor_y == VGA_HEIGHT) {
        vga_scroll_up();
        cursor_y = VGA_HEIGHT - 1;
      }
    } else
      if (fmt[i] == '\r')
        cursor_x = 0;
      else
        put_char(fmt[i]);
    }
}

void printf(char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vprintf(fmt, args);
    va_end(args);
}

void vkernel_panic(char* fmt, va_list args) {
    clear_interrupts_flag();
    printf("Kernel panic:\n");
    vprintf(fmt, args);
    endless_loop();
}

void kernel_panic(char* fmt, ...) {;
    va_list args;
    va_start(args, fmt);
    vkernel_panic(fmt, args);
    va_end(args);
}

void init_printer() {
    vga_clear_screen();
    cursor_x = 0;
    cursor_y = 0;
}

void kernel_entry() {
    init_printer();

    const size_t sizes[] = {1, 7, 19, 64, 255, 1024, 4097};
    const size_t alignments[] = {1, 4, 8, 16, 64};
    const size_t size_count = sizeof(sizes) / sizeof(sizes[0]);
    const size_t alignment_count = sizeof(alignments) / sizeof(alignments[0]);
    size_t allocations = 0;
    size_t previous_end = 0;

    printf("Immortal allocator test: 7 sizes x 5 alignments\n");
    printf("Allocations are never freed; output should scroll.\n\n");

    while (1) {
        size_t size_index = allocations % size_count;
        size_t alignment_index = allocations % alignment_count;
        size_t size = sizes[size_index];
        size_t alignment = alignments[alignment_index];
        assert(alignment != 0 && (alignment & (alignment - 1)) == 0);

        void* pointer = malloc_immortal(size, alignment);
        if (pointer == NULL)
            kernel_panic("Immortal object arena exhausted after %d allocations (next size=%d, alignment=%d)",
                         (int) allocations, (int) size, (int) alignment);

        assert(((size_t) pointer & (alignment - 1)) == 0);
        if (allocations != 0)
            assert((size_t) pointer >= previous_end);
        printf("#%d size=%d align=%d addr=%x\n",
               (int) allocations, (int) size, (int) alignment,
               (unsigned int) (size_t) pointer);
        previous_end = (size_t) pointer + size;
        allocations++;
    }
    kernel_panic("Nothing to do...");
}
