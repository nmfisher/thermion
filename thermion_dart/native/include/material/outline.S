    .global OUTLINE_OUTLINE_OFFSET;
    .global OUTLINE_OUTLINE_SIZE;

    .global OUTLINE_PACKAGE
    .section .rodata
OUTLINE_PACKAGE:
    .incbin "outline.bin"
OUTLINE_OUTLINE_OFFSET:
    .int 0
OUTLINE_OUTLINE_SIZE:
    .int 112782

