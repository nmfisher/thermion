    .global _GIZMO_GIZMO_OFFSET;
    .global _GIZMO_GIZMO_SIZE;

    .global _GIZMO_PACKAGE
    .section __TEXT,__const
_GIZMO_PACKAGE:
    .incbin "gizmo.bin"
_GIZMO_GIZMO_OFFSET:
    .int 0
_GIZMO_GIZMO_SIZE:
    .int 38039

