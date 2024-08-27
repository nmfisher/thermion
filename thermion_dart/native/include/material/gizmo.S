    .global GIZMO_GIZMO_OFFSET;
    .global GIZMO_GIZMO_SIZE;

    .global GIZMO_PACKAGE
    .section .rodata
GIZMO_PACKAGE:
    .incbin "gizmo.bin"
GIZMO_GIZMO_OFFSET:
    .int 0
GIZMO_GIZMO_SIZE:
    .int 28800

