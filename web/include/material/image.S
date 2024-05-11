    .global IMAGE_IMAGE_OFFSET;
    .global IMAGE_IMAGE_SIZE;

    .global IMAGE_PACKAGE
    .section .rodata
IMAGE_PACKAGE:
    .incbin "image.bin"
IMAGE_IMAGE_OFFSET:
    .int 0
IMAGE_IMAGE_SIZE:
    .int 17645

