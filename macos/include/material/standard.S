    .global STANDARD_STANDARD_OFFSET;
    .global STANDARD_STANDARD_SIZE;

    .global STANDARD_PACKAGE
    .section .rodata
STANDARD_PACKAGE:
    .incbin "standard.bin"
STANDARD_STANDARD_OFFSET:
    .int 0
STANDARD_STANDARD_SIZE:
    .int 1031374

