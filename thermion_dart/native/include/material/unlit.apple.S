    .global _UNLIT_UNLIT_OFFSET;
    .global _UNLIT_UNLIT_SIZE;

    .global _UNLIT_PACKAGE
    .section __TEXT,__const
_UNLIT_PACKAGE:
    .incbin "unlit.bin"
_UNLIT_UNLIT_OFFSET:
    .int 0
_UNLIT_UNLIT_SIZE:
    .int 147641

