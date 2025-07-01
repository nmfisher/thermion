    .global _OUTLINE_OUTLINE_OFFSET;
    .global _OUTLINE_OUTLINE_SIZE;

    .global _OUTLINE_PACKAGE
    .section __TEXT,__const
_OUTLINE_PACKAGE:
    .incbin "outline.bin"
_OUTLINE_OUTLINE_OFFSET:
    .int 0
_OUTLINE_OUTLINE_SIZE:
    .int 115064

