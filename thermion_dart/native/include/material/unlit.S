    .global UNLIT_UNLIT_OFFSET;
    .global UNLIT_UNLIT_SIZE;

    .global UNLIT_PACKAGE
    .section .rodata
UNLIT_PACKAGE:
    .incbin "unlit.bin"
UNLIT_UNLIT_OFFSET:
    .int 0
UNLIT_UNLIT_SIZE:
    .int 101394

