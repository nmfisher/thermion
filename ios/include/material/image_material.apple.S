    .global _IMAGE_MATERIAL_IMAGE_OFFSET;
    .global _IMAGE_MATERIAL_IMAGE_SIZE;

    .global _IMAGE_MATERIAL_PACKAGE
    .section __TEXT,__const
_IMAGE_MATERIAL_PACKAGE:
    .incbin "image_material.bin"
_IMAGE_MATERIAL_IMAGE_OFFSET:
    .int 0
_IMAGE_MATERIAL_IMAGE_SIZE:
    .int 44142

