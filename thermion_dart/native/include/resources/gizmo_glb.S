    .global GIZMO_GLB_GIZMO_OFFSET;
    .global GIZMO_GLB_GIZMO_SIZE;

    .global GIZMO_GLB_PACKAGE
    .section .rodata
GIZMO_GLB_PACKAGE:
    .incbin "gizmo_glb.bin"
GIZMO_GLB_GIZMO_OFFSET:
    .int 0
GIZMO_GLB_GIZMO_SIZE:
    .int 13184

