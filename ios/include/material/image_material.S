    .global IMAGE_MATERIAL_IMAGE_OFFSET;
    .global IMAGE_MATERIAL_IMAGE_SIZE;

    .global IMAGE_MATERIAL_PACKAGE
    .section .rodata
IMAGE_MATERIAL_PACKAGE:
    .incbin "image_material.bin"
IMAGE_MATERIAL_IMAGE_OFFSET:
    .int 0
IMAGE_MATERIAL_IMAGE_SIZE:
    .int 14141

