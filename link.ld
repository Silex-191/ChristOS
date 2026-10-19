SECTIONS {
  . = 0x7C00;

  .boot : {
    .tmp/boot.*o (.text);
  }

  .kernel : {
    *(.text);
    *(.rodata);
    *(.rodata.*);
    *(.data);
    . = ALIGN(4);
    __bss_start = .;
    *(.bss);
    *(COMMON);
    . = ALIGN(4);
    __bss_end = .;
  }

  /DISCARD/ : {
    *(.eh_frame);
    *(.note.gnu.property);
    *(.comment);
    *(.note.GNU-stack);
  }
}

