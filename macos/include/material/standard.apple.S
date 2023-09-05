    .global _STANDARD_STANDARD_OFFSET;
    .global _STANDARD_STANDARD_SIZE;

    .global _STANDARD_PACKAGE
    .section __TEXT,__const
_STANDARD_PACKAGE:
    .incbin "standard.bin"
_STANDARD_STANDARD_OFFSET:
    .int 0
_STANDARD_STANDARD_SIZE:
    .int 1031374

