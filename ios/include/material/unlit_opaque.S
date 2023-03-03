    .global UNLIT_OPAQUE_UNLIT_OFFSET;
    .global UNLIT_OPAQUE_UNLIT_SIZE;

    .global UNLIT_OPAQUE_PACKAGE
    .section .rodata
UNLIT_OPAQUE_PACKAGE:
    .incbin "unlit_opaque.bin"
UNLIT_OPAQUE_UNLIT_OFFSET:
    .int 0
UNLIT_OPAQUE_UNLIT_SIZE:
    .int 34077

