    .global _CAPTURE_UV_CAPTURE_UV_OFFSET;
    .global _CAPTURE_UV_CAPTURE_UV_SIZE;

    .global _CAPTURE_UV_PACKAGE
    .section __TEXT,__const
_CAPTURE_UV_PACKAGE:
    .incbin "capture_uv.bin"
_CAPTURE_UV_CAPTURE_UV_OFFSET:
    .int 0
_CAPTURE_UV_CAPTURE_UV_SIZE:
    .int 125851

