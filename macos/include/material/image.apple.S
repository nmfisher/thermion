    .global _IMAGE_IMAGE_OFFSET;
    .global _IMAGE_IMAGE_SIZE;

    .global _IMAGE_PACKAGE
    .section __TEXT,__const
_IMAGE_PACKAGE:
    .incbin "image.bin"
_IMAGE_IMAGE_OFFSET:
    .int 0
_IMAGE_IMAGE_SIZE:
    .int 30655

