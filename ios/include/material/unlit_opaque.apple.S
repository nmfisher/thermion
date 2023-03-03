    .global _UNLIT_OPAQUE_UNLIT_OFFSET;
    .global _UNLIT_OPAQUE_UNLIT_SIZE;

    .global _UNLIT_OPAQUE_PACKAGE
    .section __TEXT,__const
_UNLIT_OPAQUE_PACKAGE:
    .incbin "unlit_opaque.bin"
_UNLIT_OPAQUE_UNLIT_OFFSET:
    .int 0
_UNLIT_OPAQUE_UNLIT_SIZE:
    .int 34077

