    .global CAPTURE_UV_CAPTURE_UV_OFFSET;
    .global CAPTURE_UV_CAPTURE_UV_SIZE;

    .global CAPTURE_UV_PACKAGE
    .section .rodata
CAPTURE_UV_PACKAGE:
    .incbin "capture_uv.bin"
CAPTURE_UV_CAPTURE_UV_OFFSET:
    .int 0
CAPTURE_UV_CAPTURE_UV_SIZE:
    .int 125851

