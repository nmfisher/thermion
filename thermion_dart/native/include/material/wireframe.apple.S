    .global _WIREFRAME_WIREFRAME_OFFSET;
    .global _WIREFRAME_WIREFRAME_SIZE;

    .global _WIREFRAME_PACKAGE
    .section __TEXT,__const
_WIREFRAME_PACKAGE:
    .incbin "wireframe.bin"
_WIREFRAME_WIREFRAME_OFFSET:
    .int 0
_WIREFRAME_WIREFRAME_SIZE:
    .int 102151

